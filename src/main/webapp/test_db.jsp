<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ include file="dbConnection.jsp" %>
<%
    boolean available = isDatabaseAvailable();
    response.setHeader("Cache-Control", "no-store");
    if (!available) response.setStatus(503);
%>
<!doctype html>
<html lang="zh-Hant">
<head>
    <meta charset="UTF-8">
    <title>系統狀態</title>
    <link rel="stylesheet" href="css/common.css">
</head>
<body>
    <h1>系統狀態</h1>
    <p><%= available ? "系統運作正常。" : "系統暫時無法使用。" %></p>
    <a href="index.jsp">回首頁</a>
</body>
</html>
