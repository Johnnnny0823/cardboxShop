<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ include file="WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="dbConnection.jsp" %>

<%
    // 檢查用戶是否已登入
    Integer memberId = (Integer) session.getAttribute("memberId");
    if (memberId == null) {
        response.sendRedirect("member.jsp?redirect=cart.jsp");
        return;
    }

    String productIdStr = request.getParameter("product_id");
    String variantIdStr = request.getParameter("variant_id");
    String quantityStr = request.getParameter("quantity");
    
    if (productIdStr == null || quantityStr == null) {
        response.sendRedirect("card.jsp?msg=" + java.net.URLEncoder.encode("❌ 商品資訊不完整", "UTF-8"));
        return;
    }

    int productId = 0;
    int variantId = 0;
    int quantity = 1;
    
    try {
        productId = Integer.parseInt(productIdStr);
        if (variantIdStr != null && !variantIdStr.trim().isEmpty()) {
            variantId = Integer.parseInt(variantIdStr);
            if (variantId < 0) variantId = 0;
        }
        quantity = Integer.parseInt(quantityStr);
        if (quantity <= 0) quantity = 1;
    } catch (NumberFormatException e) {
        response.sendRedirect("card.jsp?msg=" + java.net.URLEncoder.encode("❌ 商品參數格式錯誤", "UTF-8"));
        return;
    }

    Connection conn = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    
    boolean dbAvailable = isDatabaseAvailable();
    if (!dbAvailable) {
        response.sendRedirect("card.jsp?msg=" + java.net.URLEncoder.encode("❌ 資料庫連接失敗，請稍後再試", "UTF-8"));
        return;
    }
    
    try {
        conn = getConnection();
        
        // 檢查商品是否存在且有庫存，並讀取限購設定
        String checkSql = "SELECT product_name, stock, price, COALESCE(max_qty_per_user, 0) AS max_qty_per_user, status FROM product WHERE product_id = ?";
        pstmt = conn.prepareStatement(checkSql);
        pstmt.setInt(1, productId);
        rs = pstmt.executeQuery();
        
        if (!rs.next()) {
            response.sendRedirect("card.jsp?msg=" + java.net.URLEncoder.encode("❌ 商品不存在或已下架", "UTF-8"));
            return;
        }
        
        String productName = rs.getString("product_name");
        int availableStock = rs.getInt("stock");
        int maxQtyPerUser = rs.getInt("max_qty_per_user");
        String status = rs.getString("status");
        rs.close();
        pstmt.close();

        if (!"上架".equals(status)) {
            response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 此商品目前已下架", "UTF-8") + "&type=error");
            return;
        }

        String variantLabel = "";
        if (variantId > 0) {
            String variantSql = "SELECT variant_name, stock FROM product_variants WHERE variant_id = ? AND product_id = ? AND is_active = 1";
            pstmt = conn.prepareStatement(variantSql);
            pstmt.setInt(1, variantId);
            pstmt.setInt(2, productId);
            rs = pstmt.executeQuery();
            if (!rs.next()) {
                response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 選擇的商品規格不存在或已停售", "UTF-8") + "&type=error");
                return;
            }
            variantLabel = "（" + rs.getString("variant_name") + "）";
            availableStock = rs.getInt("stock");
            rs.close();
            pstmt.close();
        }
        
        if (availableStock < quantity) {
            response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 庫存不足！「" + productName + variantLabel + "」目前庫存：" + availableStock + " 件", "UTF-8") + "&type=error");
            return;
        }

        // 檢查每人限購上限（含歷史未取消訂單 + 購物車內同一商品總數 + 本次欲加入數量）
        if (maxQtyPerUser > 0) {
            int boughtQty = 0;
            String boughtSql = "SELECT COALESCE(SUM(oi.quantity), 0) FROM order_item oi " +
                               "JOIN orders o ON oi.order_id = o.order_id " +
                               "WHERE o.member_id = ? AND oi.product_id = ? AND o.order_status <> '已取消'";
            pstmt = conn.prepareStatement(boughtSql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            rs = pstmt.executeQuery();
            if (rs.next()) boughtQty = rs.getInt(1);
            rs.close();
            pstmt.close();

            int inCartProductQty = 0;
            String cartSumSql = "SELECT COALESCE(SUM(quantity), 0) FROM cart_item WHERE member_id = ? AND product_id = ?";
            pstmt = conn.prepareStatement(cartSumSql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            rs = pstmt.executeQuery();
            if (rs.next()) inCartProductQty = rs.getInt(1);
            rs.close();
            pstmt.close();

            if (boughtQty + inCartProductQty + quantity > maxQtyPerUser) {
                response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 超過每人限購數量！此商品每人限購 " + maxQtyPerUser + " 件（已購 " + boughtQty + " 件、購物車 " + inCartProductQty + " 件）", "UTF-8") + "&type=error");
                return;
            }
        }
        
        // 檢查是否已在購物車中（同商品 + 同規格）
        String cartCheckSql = "SELECT quantity FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id = ?";
        pstmt = conn.prepareStatement(cartCheckSql);
        pstmt.setInt(1, memberId);
        pstmt.setInt(2, productId);
        pstmt.setInt(3, variantId);
        rs = pstmt.executeQuery();
        
        if (rs.next()) {
            int existingQuantity = rs.getInt("quantity");
            int newQuantity = existingQuantity + quantity;
            
            if (newQuantity > availableStock) {
                response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 購物車數量 + 欲加入數量超過庫存！「" + productName + variantLabel + "」目前庫存：" + availableStock + " 件", "UTF-8") + "&type=error");
                return;
            }
            
            rs.close();
            pstmt.close();
            
            String updateSql = "UPDATE cart_item SET quantity = ?, updated_at = NOW() WHERE member_id = ? AND product_id = ? AND variant_id = ?";
            pstmt = conn.prepareStatement(updateSql);
            pstmt.setInt(1, newQuantity);
            pstmt.setInt(2, memberId);
            pstmt.setInt(3, productId);
            pstmt.setInt(4, variantId);
            int result = pstmt.executeUpdate();
            
            if (result > 0) {
                response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("✅ 已更新購物車中的「" + productName + variantLabel + "」數量為 " + newQuantity + " 件", "UTF-8"));
            } else {
                response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 更新購物車失敗", "UTF-8") + "&type=error");
            }
        } else {
            rs.close();
            pstmt.close();
            
            String insertSql = "INSERT INTO cart_item (member_id, product_id, variant_id, quantity, created_at) VALUES (?, ?, ?, ?, NOW())";
            pstmt = conn.prepareStatement(insertSql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            pstmt.setInt(3, variantId);
            pstmt.setInt(4, quantity);
            int result = pstmt.executeUpdate();
            
            if (result > 0) {
                response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("✅ 「" + productName + variantLabel + "」已成功加入購物車", "UTF-8"));
            } else {
                response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode("❌ 加入購物車失敗", "UTF-8") + "&type=error");
            }
        }
        
    } catch (Exception e) {
        System.err.println("Add to cart error: " + e.getMessage());
        e.printStackTrace();
        response.sendRedirect("card.jsp?msg=" + java.net.URLEncoder.encode("❌ 加入購物車時發生錯誤，請稍後再試", "UTF-8"));
    } finally {
        closeResources(conn, pstmt, rs);
    }
%>