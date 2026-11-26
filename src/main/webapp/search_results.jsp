<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ include file="dbConnection.jsp" %>
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>搜尋與進階篩選 - cardboxShop</title>
    <link rel="stylesheet" href="css/common.css">
    <link rel="stylesheet" href="css/search_results.css">
    <style>
        .filter-bar {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 14px;
            align-items: center;
            justify-content: center;
        }
        .filter-bar select, .filter-bar input[type="number"] {
            padding: 8px 12px;
            border: 1px solid #d1d5db;
            border-radius: 6px;
            font-size: 0.92rem;
            background: #fff;
        }
        .badge-row {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin-bottom: 8px;
        }
        .tcg-badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.78rem;
            font-weight: 600;
        }
        .badge-preorder { background: #fef3c7; color: #92400e; }
        .badge-lang { background: #e0f2fe; color: #075985; }
        .badge-oos { background: #fee2e2; color: #991b1b; }
    </style>
</head>
<body>
    <%
    String query = request.getParameter("query");
    if (query == null) query = "";
    query = query.trim();

    String categoryParam = request.getParameter("category") != null ? request.getParameter("category").trim() : "";
    String rarityParam = request.getParameter("rarity") != null ? request.getParameter("rarity").trim() : "";
    String languageParam = request.getParameter("language") != null ? request.getParameter("language").trim() : "";
    String preorderParam = request.getParameter("preorder") != null ? request.getParameter("preorder").trim() : "";
    String inStockParam = request.getParameter("in_stock") != null ? request.getParameter("in_stock").trim() : "";
    String sortParam = request.getParameter("sort") != null ? request.getParameter("sort").trim() : "name_asc";

    boolean hasAnyFilter = !query.isEmpty() || !categoryParam.isEmpty() || !rarityParam.isEmpty()
                        || !languageParam.isEmpty() || !preorderParam.isEmpty() || !inStockParam.isEmpty();

    int pageSize = 12;
    int searchCurrentPage = 1;
    try {
        searchCurrentPage = Integer.parseInt(request.getParameter("page"));
        if (searchCurrentPage < 1) searchCurrentPage = 1;
    } catch (Exception e) {
        searchCurrentPage = 1;
    }
    int offset = (searchCurrentPage - 1) * pageSize;

    List<Map<String, Object>> searchResults = new ArrayList<>();
    int totalResults = 0;

    if (hasAnyFilter) {
        Connection conn = null;
        PreparedStatement pstmt = null;
        ResultSet rs = null;

        try {
            conn = getConnection();
            StringBuilder whereClause = new StringBuilder(" WHERE p.status = '上架' ");
            List<Object> params = new ArrayList<>();

            if (!query.isEmpty()) {
                whereClause.append(" AND (p.product_name LIKE ? OR p.description LIKE ? OR p.player_name LIKE ? OR p.card_series LIKE ?) ");
                String pattern = "%" + query + "%";
                params.add(pattern);
                params.add(pattern);
                params.add(pattern);
                params.add(pattern);
            }
            if (!categoryParam.isEmpty()) {
                try {
                    int catId = Integer.parseInt(categoryParam);
                    whereClause.append(" AND p.category_id = ? ");
                    params.add(catId);
                } catch (NumberFormatException ignored) {}
            }
            if (!rarityParam.isEmpty()) {
                whereClause.append(" AND p.rarity = ? ");
                params.add(rarityParam);
            }
            if (!languageParam.isEmpty()) {
                whereClause.append(" AND p.language = ? ");
                params.add(languageParam);
            }
            if ("1".equals(preorderParam)) {
                whereClause.append(" AND p.is_preorder = 1 ");
            } else if ("0".equals(preorderParam)) {
                whereClause.append(" AND p.is_preorder = 0 ");
            }
            if ("1".equals(inStockParam)) {
                whereClause.append(" AND p.stock > 0 ");
            }

            String orderBy = " ORDER BY p.product_name ASC ";
            if ("price_asc".equals(sortParam)) {
                orderBy = " ORDER BY p.price ASC ";
            } else if ("price_desc".equals(sortParam)) {
                orderBy = " ORDER BY p.price DESC ";
            } else if ("newest".equals(sortParam)) {
                orderBy = " ORDER BY p.created_at DESC ";
            }

            String countSql = "SELECT COUNT(*) AS total FROM product p " + whereClause.toString();
            pstmt = conn.prepareStatement(countSql);
            for (int i = 0; i < params.size(); i++) {
                pstmt.setObject(i + 1, params.get(i));
            }
            rs = pstmt.executeQuery();
            if (rs.next()) {
                totalResults = rs.getInt("total");
            }
            rs.close();
            pstmt.close();

            String searchSql = "SELECT p.product_id, p.product_name, p.description, p.price, p.stock, " +
                               "p.main_image, p.player_name, p.team, p.rarity, p.language, p.is_preorder, p.release_date, c.category_name " +
                               "FROM product p LEFT JOIN category c ON p.category_id = c.category_id " +
                               whereClause.toString() + orderBy + " LIMIT ? OFFSET ?";
            pstmt = conn.prepareStatement(searchSql);
            int idx = 1;
            for (Object param : params) {
                pstmt.setObject(idx++, param);
            }
            pstmt.setInt(idx++, pageSize);
            pstmt.setInt(idx, offset);
            rs = pstmt.executeQuery();

            while (rs.next()) {
                Map<String, Object> product = new HashMap<>();
                product.put("id", rs.getInt("product_id"));
                product.put("name", rs.getString("product_name"));
                product.put("description", rs.getString("description"));
                product.put("price", rs.getDouble("price"));
                product.put("stock", rs.getInt("stock"));
                product.put("image", rs.getString("main_image"));
                product.put("player", rs.getString("player_name"));
                product.put("team", rs.getString("team"));
                product.put("rarity", rs.getString("rarity"));
                product.put("language", rs.getString("language"));
                product.put("isPreorder", rs.getBoolean("is_preorder"));
                product.put("releaseDate", rs.getDate("release_date"));
                product.put("category", rs.getString("category_name"));
                searchResults.add(product);
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            closeResources(conn, pstmt, rs);
        }
    }

    int totalPages = (int) Math.ceil((double) totalResults / pageSize);
    %>

    <%@ include file="header.jsp" %>

    <div class="container">
        <div class="search-header">
            <h1>搜尋與多維商品篩選</h1>
            <div class="search-form">
                <form action="search_results.jsp" method="get">
                    <input type="text" name="query" value="<%=htmlEscape(query)%>" placeholder="搜尋卡名、系列、球員或描述...">
                    <button type="submit" class="btn btn-primary">🔍 搜尋</button>
                    <div class="filter-bar">
                        <select name="category">
                            <option value="">全部分類</option>
                            <option value="1" <%= "1".equals(categoryParam) ? "selected" : "" %>>單卡</option>
                            <option value="2" <%= "2".equals(categoryParam) ? "selected" : "" %>>卡盒</option>
                            <option value="3" <%= "3".equals(categoryParam) ? "selected" : "" %>>周邊</option>
                            <option value="4" <%= "4".equals(categoryParam) ? "selected" : "" %>>特別商品</option>
                        </select>
                        <select name="rarity">
                            <option value="">全部稀有度</option>
                            <option value="一般" <%= "一般".equals(rarityParam) ? "selected" : "" %>>一般</option>
                            <option value="稀有" <%= "稀有".equals(rarityParam) ? "selected" : "" %>>稀有</option>
                            <option value="超稀有" <%= "超稀有".equals(rarityParam) ? "selected" : "" %>>超稀有</option>
                            <option value="傳奇" <%= "傳奇".equals(rarityParam) ? "selected" : "" %>>傳奇</option>
                        </select>
                        <select name="language">
                            <option value="">全部語系</option>
                            <option value="繁體中文" <%= "繁體中文".equals(languageParam) ? "selected" : "" %>>繁體中文</option>
                            <option value="日文版" <%= "日文版".equals(languageParam) ? "selected" : "" %>>日文版</option>
                            <option value="英文版" <%= "英文版".equals(languageParam) ? "selected" : "" %>>英文版</option>
                        </select>
                        <select name="preorder">
                            <option value="">現貨與預購</option>
                            <option value="0" <%= "0".equals(preorderParam) ? "selected" : "" %>>僅看現貨</option>
                            <option value="1" <%= "1".equals(preorderParam) ? "selected" : "" %>>僅看預購</option>
                        </select>
                        <select name="in_stock">
                            <option value="">含缺貨可登記</option>
                            <option value="1" <%= "1".equals(inStockParam) ? "selected" : "" %>>僅顯示有庫存</option>
                        </select>
                        <select name="sort">
                            <option value="name_asc" <%= "name_asc".equals(sortParam) ? "selected" : "" %>>名稱 A-Z</option>
                            <option value="price_asc" <%= "price_asc".equals(sortParam) ? "selected" : "" %>>價格由低到高</option>
                            <option value="price_desc" <%= "price_desc".equals(sortParam) ? "selected" : "" %>>價格由高到低</option>
                            <option value="newest" <%= "newest".equals(sortParam) ? "selected" : "" %>>最新上架</option>
                        </select>
                    </div>
                </form>
            </div>
            
            <% if (hasAnyFilter) { %>
                <div class="search-info">
                    共找到 <strong><%=totalResults%></strong> 項符合條件的商品
                </div>
            <% } %>
        </div>

        <% if (!hasAnyFilter) { %>
            <div class="no-search">
                <h2>請輸入關鍵字或選擇篩選條件</h2>
                <p>支援依分類、稀有度、語系、預購狀態與價格排序快速找卡</p>
            </div>
        <% } else if (searchResults.isEmpty()) { %>
            <div class="no-results">
                <h2>找不到符合條件的商品</h2>
                <p>建議您放寬篩選條件，或瀏覽以下分類：</p>
                <div class="category-links">
                    <a href="card.jsp" class="btn btn-primary">瀏覽單卡</a>
                    <a href="card_box.jsp" class="btn btn-primary">瀏覽卡盒</a>
                    <a href="card_accessories.jsp" class="btn btn-primary">瀏覽周邊</a>
                    <a href="special.jsp" class="btn btn-primary">瀏覽特別商品</a>
                </div>
            </div>
        <% } else { %>
            <div class="page-info">
                顯示第 <%=(offset + 1)%> - <%=Math.min(offset + pageSize, totalResults)%> 項，共 <%=totalResults%> 項結果
            </div>

            <div class="product-grid">
                <%
                for (Map<String, Object> product : searchResults) {
                    int productId = (Integer) product.get("id");
                    String productName = (String) product.get("name");
                    String description = (String) product.get("description");
                    double price = (Double) product.get("price");
                    int stock = (Integer) product.get("stock");
                    String image = (String) product.get("image");
                    String rarity = (String) product.get("rarity");
                    String language = (String) product.get("language");
                    boolean isPreorder = Boolean.TRUE.equals(product.get("isPreorder"));
                    String category = (String) product.get("category");
                    if (image == null || image.isEmpty()) image = "images/default_product.jpg";
                %>
                <div class="product-card">
                    <a href="product_detail.jsp?id=<%=productId%>" class="product-link">
                        <div class="product-image">
                            <img src="<%=htmlEscape(image)%>" alt="<%=htmlEscape(productName)%>" class="product-img" loading="lazy" onerror="this.src='images/default_product.jpg'">
                        </div>
                    </a>
                    <div class="product-info">
                        <div class="badge-row">
                            <span class="category-badge"><%=htmlEscape(category != null ? category : "商品")%></span>
                            <% if (isPreorder) { %><span class="tcg-badge badge-preorder">預購</span><% } %>
                            <% if (language != null && !language.isEmpty()) { %><span class="tcg-badge badge-lang"><%=htmlEscape(language)%></span><% } %>
                        </div>
                        <a href="product_detail.jsp?id=<%=productId%>" class="product-name-link">
                            <h3 class="product-name"><%=htmlEscape(productName)%></h3>
                        </a>
                        <p class="product-description"><%=htmlEscape(description != null ? description : "")%></p>
                        <div class="product-price">NT$ <%=String.format("%,.0f", price)%></div>
                        <% if (rarity != null && !rarity.isEmpty()) { %>
                            <div class="rarity-badge rarity-<%=htmlEscape(rarity)%>"><%=htmlEscape(rarity)%></div>
                        <% } %>
                        <div class="product-stock">
                            <% if (stock > 5) { %>
                                <span class="in-stock">庫存充足 (<%=stock%> 件)</span>
                            <% } else if (stock > 0) { %>
                                <span class="low-stock">僅剩 <%=stock%> 件</span>
                            <% } else { %>
                                <span class="tcg-badge badge-oos">缺貨中 · 可登記補貨通知</span>
                            <% } %>
                        </div>
                    </div>
                </div>
                <% } %>
            </div>

            <% if (totalPages > 1) { %>
                <div class="pagination">
                    <% for (int i = 1; i <= totalPages; i++) { %>
                        <a href="search_results.jsp?query=<%=java.net.URLEncoder.encode(query, "UTF-8")%>&category=<%=java.net.URLEncoder.encode(categoryParam, "UTF-8")%>&rarity=<%=java.net.URLEncoder.encode(rarityParam, "UTF-8")%>&language=<%=java.net.URLEncoder.encode(languageParam, "UTF-8")%>&preorder=<%=java.net.URLEncoder.encode(preorderParam, "UTF-8")%>&in_stock=<%=java.net.URLEncoder.encode(inStockParam, "UTF-8")%>&sort=<%=java.net.URLEncoder.encode(sortParam, "UTF-8")%>&page=<%=i%>"
                           class="page-link <%= i == searchCurrentPage ? "active" : "" %>"><%=i%></a>
                    <% } %>
                </div>
            <% } %>
        <% } %>
    </div>

    <%@ include file="footer.jsp" %>
</body>
</html>