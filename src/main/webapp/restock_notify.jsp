<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ include file="WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="dbConnection.jsp" %>
<%
    Integer memberId = (Integer) session.getAttribute("memberId");
    if (memberId == null) {
        response.sendRedirect("member.jsp");
        return;
    }

    String productIdStr = request.getParameter("product_id");
    String variantIdStr = request.getParameter("variant_id");
    String action = request.getParameter("action");

    int productId = 0;
    int variantId = 0;
    try {
        productId = Integer.parseInt(productIdStr);
        if (variantIdStr != null && !variantIdStr.trim().isEmpty()) {
            variantId = Integer.parseInt(variantIdStr);
            if (variantId < 0) variantId = 0;
        }
    } catch (Exception e) {
        response.sendRedirect("index.jsp");
        return;
    }

    Connection conn = null;
    PreparedStatement pstmt = null;
    String msg = "";
    String type = "info";

    try {
        conn = getConnection();
        if ("cancel".equals(action)) {
            String sql = "UPDATE restock_notifications SET status = '已取消' WHERE member_id = ? AND product_id = ? AND variant_id = ?";
            pstmt = conn.prepareStatement(sql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            pstmt.setInt(3, variantId);
            pstmt.executeUpdate();
            msg = "已取消此商品的補貨通知登記。";
            type = "info";
        } else {
            String sql = "INSERT INTO restock_notifications (member_id, product_id, variant_id, status) " +
                         "VALUES (?, ?, ?, '等待通知') " +
                         "ON DUPLICATE KEY UPDATE status = '等待通知', created_at = CURRENT_TIMESTAMP";
            pstmt = conn.prepareStatement(sql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            pstmt.setInt(3, variantId);
            pstmt.executeUpdate();
            msg = "已成功登記補貨通知！商品補貨時將優先通知您。";
            type = "success";
        }
    } catch (Exception e) {
        e.printStackTrace();
        msg = "補貨通知登記失敗，請確認資料庫已執行 upgrade_tcg_features.sql。";
        type = "error";
    } finally {
        closeResources(conn, pstmt, null);
    }

    response.sendRedirect("product_detail.jsp?id=" + productId + "&message=" + java.net.URLEncoder.encode(msg, "UTF-8") + "&type=" + type);
%>
