/* A place to dump random javascript */

// Return a link based on the current URL to the archive...
function archive( release ) {
  URL = document.location.href;
  document.location = URL.replace(/^https?:\/\/[^\/]+/,'http://'+release+'.archive.ensembl.org');
  return true; 
}
