/* Chrome prefetches too eagerly to use <link rel="prefetch"/> */
$(function() {
  if(!prefetch) { return; }

  var i = 0;

  function blip() {
    if(i>=prefetch.length) { return; }
    var img = $('<img/>').attr({
      'src': prefetch[i],
      'style': 'display: none'
    }).appendTo($('body'));
    i++;
    setTimeout(blip,1000);
  }

  setTimeout(blip,3000);
});
