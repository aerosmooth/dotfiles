// Read-only Chrome probe: URL and media state for YouTube tabs.
function run() {
    var chrome = Application("com.google.Chrome");
    var tabs = [];
    var errors = [];
    if (!chrome.running()) {
        return JSON.stringify({ok: true, tabs: tabs});
    }
    var pageScript = '(function(){var m=navigator.mediaSession&&navigator.mediaSession.metadata;var p=Array.from(document.querySelectorAll("audio,video")).some(function(v){return !v.paused&&!v.ended;});return JSON.stringify({url:location.href,playing:p,title:m?m.title:"",artist:m?m.artist:""});})()';
    try {
        chrome.windows().forEach(function(window) {
            window.tabs().forEach(function(tab) {
                var url = tab.url();
                if (!/^https:\/\/(?:music\.youtube\.com|(?:www\.|m\.)?youtube\.com)\//.test(url)) {
                    return;
                }
                try {
                    tabs.push(JSON.parse(tab.execute({javascript: pageScript})));
                } catch (error) {
                    errors.push(String(error));
                }
            });
        });
    } catch (error) {
        errors.push(String(error));
    }
    return JSON.stringify({ok: errors.length === 0, tabs: tabs, errors: errors});
}
