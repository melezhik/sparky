function openTab(evt, tabName) {
  var i, x, tablinks;
  x = document.getElementsByClassName("content-tab");
  for (i = 0; i < x.length; i++) {
      x[i].style.display = "none";
  }
  tablinks = document.getElementsByClassName("tab");
  for (i = 0; i < x.length; i++) {
      tablinks[i].className = tablinks[i].className.replace(" is-active", "");
  }
  document.getElementById(tabName).style.display = "block";
  evt.currentTarget.className += " is-active";
}

//tab = window.location.hash.replace("#", "") || "Report";
//tab = tab.replace("/", "");
//alert(tab)

if (tab != "Report") {
  document.getElementById(tab).click();
}

function getSelectValues(elm) {
  var result = [];
  var options = elm && elm.options;
  var opt;
  for (var i=0, iLen=options.length; i<iLen; i++) {
    opt = options[i];
    if (opt.selected) {
     result.push(opt.value || opt.text);
    }
  }
  return result;
}
