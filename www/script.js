Shiny.addCustomMessageHandler('show_overlay', function(message) {
    document.getElementById('loading-overlay').style.display = 'flex';
});

Shiny.addCustomMessageHandler('hide_overlay', function(message) {
    document.getElementById('loading-overlay').style.display = 'none';
});