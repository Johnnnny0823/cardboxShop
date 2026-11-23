function submitStorePost(action, fields) {
    const form = document.createElement('form');
    form.method = 'post';
    form.action = action;
    for (const [name, value] of Object.entries(fields)) {
        const field = document.createElement('input');
        field.type = 'hidden';
        field.name = name;
        field.value = value;
        form.appendChild(field);
    }
    document.body.appendChild(form);
    form.submit();
}
