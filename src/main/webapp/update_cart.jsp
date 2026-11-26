<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="dbConnection.jsp" %>
<%@ page import="java.sql.*" %>

<%
    Integer memberId = (Integer) session.getAttribute("memberId");
    if (memberId == null) {
        response.sendRedirect("member.jsp?redirect=cart.jsp");
        return;
    }

    String action = request.getParameter("action");
    String productIdStr = request.getParameter("productId");
    String variantIdStr = request.getParameter("variantId");
    String quantityStr = request.getParameter("quantity");

    int variantId = 0;
    if (variantIdStr != null && !variantIdStr.trim().isEmpty()) {
        try {
            variantId = Integer.parseInt(variantIdStr);
            if (variantId < 0) variantId = 0;
        } catch (NumberFormatException ignored) {
            variantId = 0;
        }
    }

    Connection conn = null;
    PreparedStatement pstmt = null;
    ResultSet rs = null;
    String message = "";

    boolean dbAvailable = isDatabaseAvailable();
    if (!dbAvailable) {
        response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("資料庫連接異常，無法更新購物車", "UTF-8"));
        return;
    }

    try {
        conn = getConnection();
        
        if ("remove".equals(action) && productIdStr != null) {
            int productId = Integer.parseInt(productIdStr);
            String deleteSql = "DELETE FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id = ?";
            pstmt = conn.prepareStatement(deleteSql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            pstmt.setInt(3, variantId);
            int result = pstmt.executeUpdate();
            
            if (result > 0) {
                message = "✅ 商品已成功從購物車移除";
            } else {
                message = "❌ 移除商品失敗，商品可能已不在購物車中";
            }
            
        } else if (("update".equals(action) || "increase".equals(action) || "decrease".equals(action)) && productIdStr != null) {
            int productId = Integer.parseInt(productIdStr);
            int newQuantity = 1;
            int currentVariantQty = 0;

            String getCurrentQtySql = "SELECT quantity FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id = ?";
            pstmt = conn.prepareStatement(getCurrentQtySql);
            pstmt.setInt(1, memberId);
            pstmt.setInt(2, productId);
            pstmt.setInt(3, variantId);
            rs = pstmt.executeQuery();

            if (!rs.next()) {
                response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("❌ 商品不在購物車中", "UTF-8"));
                return;
            }
            currentVariantQty = rs.getInt("quantity");
            rs.close();
            pstmt.close();

            if ("increase".equals(action)) {
                newQuantity = currentVariantQty + 1;
            } else if ("decrease".equals(action)) {
                newQuantity = currentVariantQty - 1;
                if (newQuantity <= 0) {
                    String deleteSql = "DELETE FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id = ?";
                    pstmt = conn.prepareStatement(deleteSql);
                    pstmt.setInt(1, memberId);
                    pstmt.setInt(2, productId);
                    pstmt.setInt(3, variantId);
                    pstmt.executeUpdate();
                    response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("✅ 商品數量歸零，已從購物車移除", "UTF-8"));
                    return;
                }
            } else if ("update".equals(action) && quantityStr != null) {
                try {
                    newQuantity = Integer.parseInt(quantityStr);
                    if (newQuantity <= 0) {
                        String deleteSql = "DELETE FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id = ?";
                        pstmt = conn.prepareStatement(deleteSql);
                        pstmt.setInt(1, memberId);
                        pstmt.setInt(2, productId);
                        pstmt.setInt(3, variantId);
                        pstmt.executeUpdate();
                        response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("✅ 商品數量歸零，已從購物車移除", "UTF-8"));
                        return;
                    }
                } catch (NumberFormatException e) {
                    response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode("❌ 數量格式錯誤，請輸入有效數字", "UTF-8"));
                    return;
                }
            }

            // 檢查庫存與限購
            String stockCheckSql = "SELECT p.stock, p.product_name, COALESCE(p.max_qty_per_user, 0) AS max_qty_per_user, " +
                                   "pv.stock AS variant_stock, pv.variant_name " +
                                   "FROM product p " +
                                   "LEFT JOIN product_variants pv ON pv.variant_id = ? AND pv.product_id = p.product_id AND pv.is_active = 1 " +
                                   "WHERE p.product_id = ?";
            pstmt = conn.prepareStatement(stockCheckSql);
            pstmt.setInt(1, variantId);
            pstmt.setInt(2, productId);
            rs = pstmt.executeQuery();
            
            if (rs.next()) {
                int stock = variantId > 0 ? rs.getInt("variant_stock") : rs.getInt("stock");
                if (variantId > 0 && rs.getString("variant_name") == null) {
                    message = "❌ 此商品規格已停售";
                } else {
                    String productName = rs.getString("product_name");
                    int maxQtyPerUser = rs.getInt("max_qty_per_user");
                    rs.close();
                    pstmt.close();

                    boolean limitExceeded = false;
                    if (maxQtyPerUser > 0) {
                        int boughtQty = 0;
                        pstmt = conn.prepareStatement(
                            "SELECT COALESCE(SUM(oi.quantity), 0) FROM order_item oi " +
                            "JOIN orders o ON oi.order_id = o.order_id " +
                            "WHERE o.member_id = ? AND oi.product_id = ? AND o.order_status <> '已取消'"
                        );
                        pstmt.setInt(1, memberId);
                        pstmt.setInt(2, productId);
                        rs = pstmt.executeQuery();
                        if (rs.next()) boughtQty = rs.getInt(1);
                        rs.close();
                        pstmt.close();

                        int otherVariantsInCart = 0;
                        pstmt = conn.prepareStatement(
                            "SELECT COALESCE(SUM(quantity), 0) FROM cart_item WHERE member_id = ? AND product_id = ? AND variant_id <> ?"
                        );
                        pstmt.setInt(1, memberId);
                        pstmt.setInt(2, productId);
                        pstmt.setInt(3, variantId);
                        rs = pstmt.executeQuery();
                        if (rs.next()) otherVariantsInCart = rs.getInt(1);
                        rs.close();
                        pstmt.close();

                        if (boughtQty + otherVariantsInCart + newQuantity > maxQtyPerUser) {
                            message = "❌ 超過每人限購數量！「" + productName + "」每人限購 " + maxQtyPerUser + " 件";
                            limitExceeded = true;
                        }
                    }

                    if (!limitExceeded) {
                        if (newQuantity > stock) {
                            message = "❌ 數量超過庫存！「" + productName + "」目前庫存：" + stock + " 件";
                        } else {
                            String updateSql = "UPDATE cart_item SET quantity = ?, updated_at = NOW() " +
                                             "WHERE member_id = ? AND product_id = ? AND variant_id = ?";
                            pstmt = conn.prepareStatement(updateSql);
                            pstmt.setInt(1, newQuantity);
                            pstmt.setInt(2, memberId);
                            pstmt.setInt(3, productId);
                            pstmt.setInt(4, variantId);
                            
                            int result = pstmt.executeUpdate();
                            if (result > 0) {
                                message = "✅ 購物車已成功更新數量為 " + newQuantity;
                            } else {
                                message = "❌ 更新失敗，商品可能已不在購物車中";
                            }
                        }
                    }
                }
            } else {
                message = "❌ 商品不存在或已下架";
            }
        } else {
            message = "❌ 操作參數錯誤";
        }
        
    } catch (NumberFormatException e) {
        message = "❌ 商品ID格式錯誤";
    } catch (Exception e) {
        message = "❌ 操作失敗：" + e.getMessage();
        e.printStackTrace();
    } finally {
        closeResources(conn, pstmt, rs);
    }

    response.sendRedirect("cart.jsp?msg=" + java.net.URLEncoder.encode(message, "UTF-8"));
%>
