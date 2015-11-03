/* Chrome prefetches too eagerly to use <link rel="prefetch"/> */
$(function() {
  if(!prefetch) { return; }

  var i = 0;

  function blip() {
    if(i>=prefetch.length) { return; }
    $.get(prefetch[i]);
    i++;
    setTimeout(blip,1000);
  }

  setTimeout(blip,3000);
});
