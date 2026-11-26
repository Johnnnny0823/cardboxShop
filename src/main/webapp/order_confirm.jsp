<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ include file="WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="dbConnection.jsp" %>
<%
// 檢查登入狀態
Integer memberId = (Integer) session.getAttribute("memberId");
if (memberId == null) {
    response.sendRedirect("member.jsp");
    return;
}

// 獲取表單參數
String shippingName = request.getParameter("shipping_name");
String shippingPhone = request.getParameter("shipping_phone");
String shippingAddress = request.getParameter("shipping_address");
String orderNote = request.getParameter("order_note");
String paymentMethod = request.getParameter("payment_method");

if (shippingName == null || shippingPhone == null || shippingAddress == null || paymentMethod == null ||
    shippingName.trim().isEmpty() || shippingPhone.trim().isEmpty() || shippingAddress.trim().isEmpty()) {
    response.sendRedirect("checkout.jsp?message=" + java.net.URLEncoder.encode("請填寫完整資訊", "UTF-8") + "&type=error");
    return;
}

Connection conn = null;
PreparedStatement pstmt = null;
ResultSet rs = null;
String message = "";
String messageType = "error";

try {
    conn = getConnection();
    conn.setAutoCommit(false); // 開始交易
    
    // 使用 FOR UPDATE 鎖定購物車對應的商品與變體庫存列，防止搶購併發超賣
    String cartSql = "SELECT c.product_id, c.variant_id, c.quantity, p.product_name, " +
                     "COALESCE(pv.price, p.price) AS effective_price, " +
                     "COALESCE(pv.stock, p.stock) AS effective_stock, " +
                     "pv.variant_name, COALESCE(p.max_qty_per_user, 0) AS max_qty_per_user " +
                     "FROM cart_item c " +
                     "JOIN product p ON c.product_id = p.product_id " +
                     "LEFT JOIN product_variants pv ON c.variant_id > 0 AND pv.variant_id = c.variant_id AND pv.product_id = p.product_id " +
                     "WHERE c.member_id = ? FOR UPDATE";
    pstmt = conn.prepareStatement(cartSql);
    pstmt.setInt(1, memberId);
    rs = pstmt.executeQuery();
    
    double totalAmount = 0.0;
    java.util.List<java.util.Map<String, Object>> cartItems = new java.util.ArrayList<>();
    java.util.Map<Integer, Integer> productQtyInOrder = new java.util.HashMap<>();
    java.util.Map<Integer, Integer> productLimitMap = new java.util.HashMap<>();
    java.util.Map<Integer, String> productNameMap = new java.util.HashMap<>();
    
    while (rs.next()) {
        int productId = rs.getInt("product_id");
        int variantId = rs.getInt("variant_id");
        int quantity = rs.getInt("quantity");
        String productName = rs.getString("product_name");
        String variantName = rs.getString("variant_name");
        double price = rs.getDouble("effective_price");
        int stock = rs.getInt("effective_stock");
        int maxQtyPerUser = rs.getInt("max_qty_per_user");

        if (variantId > 0 && variantName == null) {
            throw new Exception("商品「" + productName + "」的指定規格已停售，請先移除後再結帳。");
        }
        
        String displayLabel = variantName != null ? productName + "（" + variantName + "）" : productName;
        if (stock < quantity) {
            throw new Exception("商品「" + displayLabel + "」庫存不足！（剩餘 " + stock + " 件）");
        }
        
        double itemTotal = price * quantity;
        totalAmount += itemTotal;
        
        java.util.Map<String, Object> item = new java.util.HashMap<>();
        item.put("productId", productId);
        item.put("variantId", variantId);
        item.put("variantName", variantName);
        item.put("quantity", quantity);
        item.put("price", price);
        cartItems.add(item);

        productQtyInOrder.put(productId, productQtyInOrder.getOrDefault(productId, 0) + quantity);
        productLimitMap.put(productId, maxQtyPerUser);
        productNameMap.put(productId, productName);
    }
    rs.close();
    pstmt.close();
    
    if (cartItems.isEmpty()) {
        throw new Exception("購物車是空的！");
    }

    // 檢查每人限購數量（歷史未取消訂單 + 本次結帳數量）
    for (java.util.Map.Entry<Integer, Integer> entry : productQtyInOrder.entrySet()) {
        int pid = entry.getKey();
        int orderQty = entry.getValue();
        int limit = productLimitMap.getOrDefault(pid, 0);
        if (limit > 0) {
            String boughtSql = "SELECT COALESCE(SUM(oi.quantity), 0) FROM order_item oi " +
                               "JOIN orders o ON oi.order_id = o.order_id " +
                               "WHERE o.member_id = ? AND oi.product_id = ? AND o.order_status <> '已取消'";
            pstmt = conn.prepareStatement(boughtSql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, pid);
            rs = pstmt.executeQuery();
            int boughtQty = rs.next() ? rs.getInt(1) : 0;
            rs.close();
            pstmt.close();
            if (boughtQty + orderQty > limit) {
                throw new Exception("商品「" + productNameMap.get(pid) + "」超過每人限購 " + limit + " 件上限！");
            }
        }
    }
    
    // 與 cart.jsp / checkout.jsp 統一免運門檻：滿 NT$2,000 免運，否則 NT$100
    double freeShippingThreshold = 2000.0;
    double shippingFee = totalAmount >= freeShippingThreshold ? 0.0 : 100.0;
    if ("貨到付款".equals(paymentMethod)) {
        shippingFee += 30.0; // 貨到付款手續費
    }
    double finalAmount = totalAmount + shippingFee;
    
    // 創建訂單
    String orderSql = "INSERT INTO orders (member_id, total_amount, shipping_fee, final_amount, " +
                    "payment_method, shipping_name, shipping_phone, shipping_address, order_note) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
    pstmt = conn.prepareStatement(orderSql, Statement.RETURN_GENERATED_KEYS);
    pstmt.setInt(1, memberId);
    pstmt.setDouble(2, totalAmount);
    pstmt.setDouble(3, shippingFee);
    pstmt.setDouble(4, finalAmount);
    pstmt.setString(5, paymentMethod);
    pstmt.setString(6, shippingName.trim());
    pstmt.setString(7, shippingPhone.trim());
    pstmt.setString(8, shippingAddress.trim());
    pstmt.setString(9, orderNote != null ? orderNote.trim() : "");
    
    int result = pstmt.executeUpdate();
    if (result == 0) {
        throw new Exception("建立訂單失敗！");
    }
    
    rs = pstmt.getGeneratedKeys();
    int orderId = 0;
    if (rs.next()) {
        orderId = rs.getInt(1);
    }
    rs.close();
    pstmt.close();
    
    // 插入訂單明細（含變體資訊）
    String itemSql = "INSERT INTO order_item (order_id, item_sequence, product_id, variant_id, variant_name, quantity, price) " +
                   "VALUES (?, ?, ?, ?, ?, ?, ?)";
    pstmt = conn.prepareStatement(itemSql);
    
    for (int i = 0; i < cartItems.size(); i++) {
        java.util.Map<String, Object> item = cartItems.get(i);
        pstmt.setInt(1, orderId);
        pstmt.setInt(2, i + 1);
        pstmt.setInt(3, (Integer) item.get("productId"));
        pstmt.setInt(4, (Integer) item.get("variantId"));
        String vName = (String) item.get("variantName");
        if (vName != null) {
            pstmt.setString(5, vName);
        } else {
            pstmt.setNull(5, Types.VARCHAR);
        }
        pstmt.setInt(6, (Integer) item.get("quantity"));
        pstmt.setDouble(7, (Double) item.get("price"));
        pstmt.executeUpdate();
    }
    pstmt.close();
    
    // 安全扣減商品／變體庫存（附加 stock >= ? 條件雙重保險）
    String updateProductStockSql = "UPDATE product SET stock = stock - ? WHERE product_id = ? AND stock >= ?";
    String updateVariantStockSql = "UPDATE product_variants SET stock = stock - ? WHERE variant_id = ? AND stock >= ?";
    
    for (java.util.Map<String, Object> item : cartItems) {
        int qty = (Integer) item.get("quantity");
        int pid = (Integer) item.get("productId");
        int vid = (Integer) item.get("variantId");
        if (vid > 0) {
            pstmt = conn.prepareStatement(updateVariantStockSql);
            pstmt.setInt(1, qty);
            pstmt.setInt(2, vid);
            pstmt.setInt(3, qty);
            if (pstmt.executeUpdate() == 0) {
                throw new Exception("併發搶購導致規格庫存不足，請重新確認購物車！");
            }
            pstmt.close();
        } else {
            pstmt = conn.prepareStatement(updateProductStockSql);
            pstmt.setInt(1, qty);
            pstmt.setInt(2, pid);
            pstmt.setInt(3, qty);
            if (pstmt.executeUpdate() == 0) {
                throw new Exception("併發搶購導致商品庫存不足，請重新確認購物車！");
            }
            pstmt.close();
        }
    }
    
    // 清空購物車
    String clearCartSql = "DELETE FROM cart_item WHERE member_id = ?";
    pstmt = conn.prepareStatement(clearCartSql);
    pstmt.setInt(1, memberId);
    pstmt.executeUpdate();
    
    conn.commit(); // 提交交易
    
    response.sendRedirect("order_success.jsp?orderId=" + orderId);
    return;
    
} catch (Exception e) {
    if (conn != null) {
        try {
            conn.rollback();
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
    }
    message = "訂單建立失敗：" + e.getMessage();
    e.printStackTrace();
} finally {
    if (conn != null) {
        try {
            conn.setAutoCommit(true);
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
    closeResources(conn, pstmt, rs);
}

response.sendRedirect("checkout.jsp?message=" + java.net.URLEncoder.encode(message, "UTF-8") + "&type=" + messageType);
%>