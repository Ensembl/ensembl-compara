// Javascript to do collapsible hierarchical menus

function exp_coll(ind)

{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (s.style.display == 'none')
 {
   s.style.display = 'block';
   i.src = "/img/minus.gif";
 }
 else if (s.style.display == 'block')
 {
   s.style.display = 'none';
   i.src = "/img/plus.gif";
 }
}

function exp(ind)
{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (!(s && i)) return false;
 s.style.display = 'block';
 i.src = "/img/minus.gif";
}

function coll(ind)
{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (!(s && i)) return false;
 s.style.display = 'none';
 i.src = "/img/plus.gif";
}

function coll_all()
{

 coll(0);
}

function exp_all()
{

 exp(0);
}
