<%@ page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="../WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="/WEB-INF/require_admin_csrf.jspf" %>
<%@ include file="../dbConnection.jsp" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.math.BigDecimal" %>

<%
    // 權限檢查：只有管理員才能訪問此頁面
    String memberLevel = (String) session.getAttribute("memberLevel");
    if (memberLevel == null || !"管理員".equals(memberLevel)) {
        response.sendRedirect("../index.jsp");
        return;
    }

    Connection conn = null;
    PreparedStatement pstmt = null;
    String message = "";
    String messageType = "error";

    try {
        // 獲取表單數據
        int productId = Integer.parseInt(request.getParameter("product_id"));
        String productName = request.getParameter("product_name");
        BigDecimal price = new BigDecimal(request.getParameter("price"));
        int stock = Integer.parseInt(request.getParameter("stock"));
        String status = request.getParameter("status");
        String description = request.getParameter("description");
        String language = request.getParameter("language");
        if (language == null || language.trim().isEmpty()) language = "英文版";
        int isPreorder = "1".equals(request.getParameter("is_preorder")) ? 1 : 0;
        String releaseDateStr = request.getParameter("release_date");
        int maxQtyPerUser = 0;
        try {
            maxQtyPerUser = Math.max(0, Integer.parseInt(request.getParameter("max_qty_per_user")));
        } catch (Exception ignored) {}
        
        // 更新資料庫
        conn = getConnection();
        String sql = "UPDATE product SET product_name = ?, price = ?, stock = ?, status = ?, description = ?, " +
                     "language = ?, is_preorder = ?, release_date = ?, max_qty_per_user = ? WHERE product_id = ?";
        pstmt = conn.prepareStatement(sql);
        pstmt.setString(1, productName);
        pstmt.setBigDecimal(2, price);
        pstmt.setInt(3, stock);
        pstmt.setString(4, status);
        pstmt.setString(5, description);
        pstmt.setString(6, language);
        pstmt.setInt(7, isPreorder);
        if (releaseDateStr != null && !releaseDateStr.trim().isEmpty()) {
            pstmt.setDate(8, java.sql.Date.valueOf(releaseDateStr.trim()));
        } else {
            pstmt.setNull(8, Types.DATE);
        }
        pstmt.setInt(9, maxQtyPerUser);
        pstmt.setInt(10, productId);
        
        int result = pstmt.executeUpdate();
        pstmt.close();

        // 若管理員有填寫新變體，則一併新增至 product_variants
        String newVarName = request.getParameter("new_variant_name");
        String newVarGrade = request.getParameter("new_variant_grade");
        String newVarPrice = request.getParameter("new_variant_price");
        String newVarStock = request.getParameter("new_variant_stock");
        if (newVarName != null && !newVarName.trim().isEmpty() && newVarPrice != null && !newVarPrice.trim().isEmpty()) {
            String varSql = "INSERT INTO product_variants (product_id, variant_name, condition_grade, price, stock) VALUES (?, ?, ?, ?, ?)";
            pstmt = conn.prepareStatement(varSql);
            pstmt.setInt(1, productId);
            pstmt.setString(2, newVarName.trim());
            pstmt.setString(3, (newVarGrade != null && !newVarGrade.trim().isEmpty()) ? newVarGrade.trim() : "Sealed");
            pstmt.setBigDecimal(4, new BigDecimal(newVarPrice.trim()));
            int vStock = 0;
            try { vStock = Math.max(0, Integer.parseInt(newVarStock.trim())); } catch (Exception ignored) {}
            pstmt.setInt(5, vStock);
            pstmt.executeUpdate();
        }
        
        if (result > 0) {
            message = "商品更新成功！";
            messageType = "success";
        } else {
            message = "商品更新失敗，請重試。";
        }
        
    } catch (Exception e) {
        message = "更新商品時發生錯誤: " + e.getMessage();
        e.printStackTrace();
    } finally {
        closeResources(conn, pstmt, null);
    }
    
    // 重定向回商品列表頁面，並帶上訊息
    response.sendRedirect("admin_products.jsp?msg=" + java.net.URLEncoder.encode(message, "UTF-8") + "&msgType=" + messageType);
%> 