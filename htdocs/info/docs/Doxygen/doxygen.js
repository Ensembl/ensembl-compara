$(function () {
  setTimeout(function () {
    if (window.location.href.indexOf('Doxygen') !== -1) {
      var doxygenBreadcrumbs = $('#nav-path').find('li').removeClass();
      var breadcrumbs        = $('#main').children('.breadcrumbs');
      
      breadcrumbs.append('<li><a href="' + window.location.href.replace(/(.+)\/.+\.html/, '$1/index.html') +'">' + document.title.split(':')[0] + '</a></li>');
      
      if (doxygenBreadcrumbs.length) {
        breadcrumbs.append(doxygenBreadcrumbs);
      }
      
      breadcrumbs.find('li.last').removeClass('last').siblings(':last').addClass('last');
      
      breadcrumbs = doxygenBreadcrumbs = null;
    }
    
    function resize() {
      var outerHeight = $(window).height() - $('#doxygen').offset().top - 85;
      var innerHeight = outerHeight - $('#nav-path').height() - $('#top').height();
      $('#doxygen').height(outerHeight);
      $('#side-nav, #nav-tree, #doc-content, #pdoc_iframe').height(innerHeight);
    }
    
    if ($('body').not('.ie67').length) {
      $(window).resize(resize);
      resize();
    }
  }, 1);
});


/**
 * jQuery.ScrollTo - Easy element scrolling using jQuery.
 * Copyright (c) 2008 Ariel Flesler - aflesler(at)gmail(dot)com
 * Licensed under GPL license (http://www.opensource.org/licenses/gpl-license.php).
 * Date: 2/8/2008
 * @author Ariel Flesler
 * @version 1.3.2
 */
(function($){var o=$.scrollTo=function(a,b,c){o.window().scrollTo(a,b,c)};o.defaults={axis:'y',duration:1};o.window=function(){return $($.browser.safari?'body':'html')};$.fn.scrollTo=function(l,m,n){if(typeof m=='object'){n=m;m=0}n=$.extend({},o.defaults,n);m=m||n.speed||n.duration;n.queue=n.queue&&n.axis.length>1;if(n.queue)m/=2;n.offset=j(n.offset);n.over=j(n.over);return this.each(function(){var a=this,b=$(a),t=l,c,d={},w=b.is('html,body');switch(typeof t){case'number':case'string':if(/^([+-]=)?\d+(px)?$/.test(t)){t=j(t);break}t=$(t,this);case'object':if(t.is||t.style)c=(t=$(t)).offset()}$.each(n.axis.split(''),function(i,f){var P=f=='x'?'Left':'Top',p=P.toLowerCase(),k='scroll'+P,e=a[k],D=f=='x'?'Width':'Height';if(c){d[k]=c[p]+(w?0:e-b.offset()[p]);if(n.margin){d[k]-=parseInt(t.css('margin'+P))||0;d[k]-=parseInt(t.css('border'+P+'Width'))||0}d[k]+=n.offset[p]||0;if(n.over[p])d[k]+=t[D.toLowerCase()]()*n.over[p]}else d[k]=t[p];if(/^\d+$/.test(d[k]))d[k]=d[k]<=0?0:Math.min(d[k],h(D));if(!i&&n.queue){if(e!=d[k])g(n.onAfterFirst);delete d[k]}});g(n.onAfter);function g(a){b.animate(d,m,n.easing,a&&function(){a.call(this,l)})};function h(D){var b=w?$.browser.opera?document.body:document.documentElement:a;return b['scroll'+D]-b['client'+D]}})};function j(a){return typeof a=='object'?a:{top:a,left:a}}})(jQuery);
