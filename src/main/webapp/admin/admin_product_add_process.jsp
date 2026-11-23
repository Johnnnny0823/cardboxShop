<%@ page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="../WEB-INF/require_same_origin_post.jspf" %>
<%@ include file="/WEB-INF/require_admin.jspf" %>
<%@ include file="/WEB-INF/admin_csrf.jspf" %>
<%@ include file="../dbConnection.jsp" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.math.BigDecimal" %>
<%@ page import="java.io.*, java.util.*, javax.servlet.*, javax.servlet.http.*" %>
<%@ page import="org.apache.commons.fileupload.*, org.apache.commons.fileupload.disk.*, org.apache.commons.fileupload.servlet.*" %>

<%
    Connection conn = null;
    PreparedStatement pstmt = null;
    List<FileItem> items = Collections.emptyList();
    String message = "";
    String messageType = "error";

    try {
        // 設定表單解析器及上傳大小限制
        DiskFileItemFactory factory = new DiskFileItemFactory();
        ServletFileUpload upload = new ServletFileUpload(factory);
        upload.setSizeMax(10 * 1024 * 1024); // 限制檔案大小為 10MB
        upload.setFileCountMax(20);

        // 解析請求
        items = upload.parseRequest(request);
        String csrf = null;
        for (FileItem item : items) {
            if (item.isFormField() && "csrf_token".equals(item.getFieldName())) {
                if (csrf != null) {
                    response.sendError(403);
                    return;
                }
                csrf = item.getString("UTF-8");
            }
        }
        if (!validAdminCsrf(session, csrf)) {
            response.sendError(403);
            return;
        }

        String uploadPath = application.getRealPath("/") + "images/products";
        File uploadDir = new File(uploadPath);
        if (!uploadDir.exists()) {
            uploadDir.mkdirs();
        }
        // 初始化變數
        String productName = "";
        BigDecimal price = null;
        int stock = 0;
        String status = "";
        String description = "";
        String mainImage = "";
        int categoryId = 0;
        String playerName = "";
        String team = "";
        String cardYear = "";
        String cardSeries = "";
        String rarity = "";
        String cardCondition = "";

        // 處理表單資料
        for (FileItem item : items) {
            if (item.isFormField()) {
                // 處理一般表單欄位
                String fieldName = item.getFieldName();
                String value = item.getString("UTF-8");
                
                switch (fieldName) {
                    case "product_name": productName = value; break;
                    case "price": price = new BigDecimal(value); break;
                    case "stock": stock = Integer.parseInt(value); break;
                    case "status": status = value; break;
                    case "description": description = value; break;
                    case "category_id": categoryId = Integer.parseInt(value); break;
                    case "player_name": playerName = value; break;
                    case "team": team = value; break;
                    case "card_year": cardYear = value; break;
                    case "card_series": cardSeries = value; break;
                    case "rarity": rarity = value; break;
                    case "card_condition": cardCondition = value; break;
                }
            } else {
                // 處理檔案上傳
                if (item.getFieldName().equals("productImage") && item.getSize() > 0) {
                    String fileName = new File(item.getName()).getName();
                    // 生成唯一檔名
                    String uniqueFileName = System.currentTimeMillis() + "_" + fileName;
                    File uploadedFile = new File(uploadPath + File.separator + uniqueFileName);
                    item.write(uploadedFile);
                    mainImage = "images/products/" + uniqueFileName;
                }
            }
        }

        // 驗證必填欄位
        if (productName.isEmpty() || price == null || stock < 0 || status.isEmpty() || 
            description.isEmpty() || mainImage.isEmpty() || categoryId == 0) {
            message = "所有必填欄位都必須填寫！";
            response.sendRedirect("admin_product_add.jsp?msg=" + java.net.URLEncoder.encode(message, "UTF-8") + "&msgType=" + messageType);
            return;
        }

        // 連接資料庫並插入新商品
        conn = getConnection();
        String sql = "INSERT INTO product (category_id, product_name, price, stock, status, description, main_image, " +
                    "player_name, team, card_year, card_series, rarity, card_condition) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        pstmt = conn.prepareStatement(sql);
        pstmt.setInt(1, categoryId);
        pstmt.setString(2, productName);
        pstmt.setBigDecimal(3, price);
        pstmt.setInt(4, stock);
        pstmt.setString(5, status);
        pstmt.setString(6, description);
        pstmt.setString(7, mainImage);
        pstmt.setString(8, playerName);
        pstmt.setString(9, team);
        pstmt.setString(10, cardYear);
        pstmt.setString(11, cardSeries);
        pstmt.setString(12, rarity);
        pstmt.setString(13, cardCondition);

        int result = pstmt.executeUpdate();

        if (result > 0) {
            message = "商品新增成功！";
            messageType = "success";
        } else {
            message = "商品新增失敗，請重試。";
        }

    } catch (Exception e) {
        message = "新增商品時發生錯誤: " + e.getMessage();
        e.printStackTrace();
    } finally {
        for (FileItem item : items) item.delete();
        closeResources(conn, pstmt, null);
    }

    // 重定向回商品列表頁面，並帶上訊息
    response.sendRedirect("admin_products.jsp?msg=" + java.net.URLEncoder.encode(message, "UTF-8") + "&msgType=" + messageType);
%>
