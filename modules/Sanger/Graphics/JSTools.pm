#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::JSTools;
use strict;

use vars qw/@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( js_popup js_menu_header js_menu_div js_menu js_tooltip_header js_tooltip_div js_tooltip js_init);

########################################
 #####    ####   #####   #    #  #####
 #    #  #    #  #    #  #    #  #    #
 #    #  #    #  #    #  #    #  #    #
 #####   #    #  #####   #    #  #####
 #       #    #  #       #    #  #
 #        ####   #        ####   #
#########################################

sub js_popup {
    my ($url, $target, $attribs) = @_;
    $target ||= "ens_popup";
    $attribs ||= "width=450,height=600,status=no,resizable=yes,toolbar=no,scrollbars=yes,location=no";
    return "javascript:void(window.open(\'$url\', \'$target\', \'$attribs\'));";
}

################################################
 ######          #    #  ######  #    #  #    #
     #           ##  ##  #       ##   #  #    #
    #    #####   # ## #  #####   # #  #  #    #
   #             #    #  #       #  # #  #    #
  #              #    #  #       #   ##  #    #
 ######          #    #  ######  #    #   ####
################################################

#########
# should be printed inside <head>..</head>
#
sub js_menu_header {
    return '<script language="javascript" src="/js/zmenu.js"></script>';
}

#########
# should be printed just after <body>
#
sub js_menu_div {
    return '<div id="jstooldiv" style="position: absolute;visibility: hidden;"></div>';
}

#########
# hash with caption=>'menu title' and 'menu item'=>href
#   Can produce a sorted menu by prepending dd: to the menu key.  These
#   are then pruned off - e.g. "01:toast" as a key would be sorted first,
#   and produce a menu item "toast".
#
sub js_menu {
    my $items = shift;
    return "javascript:void($items);" unless ref($items) eq 'HASH';
    my $str = "\'" . ($items->{'caption'} || "options") . "\',";

    for my $i (sort keys %$items) {
        next if $i eq 'caption';
    	my $menu_line = $i || "";
    	$menu_line =~ s/^\d\d://;
	my $item = $items->{$i} || "";
    	$str .= "\'" . $item . "\',\'" . $menu_line . "\',";
    }

    $str =~ s/(.*),/$1/;
    return "javascript:void(zmenu($str));";
}

########################################################################
 ######           #####   ####    ####   #        #####     #    #####
     #              #    #    #  #    #  #          #       #    #    #
    #    #####      #    #    #  #    #  #          #       #    #    #
   #                #    #    #  #    #  #          #       #    #####
  #                 #    #    #  #    #  #          #       #    #
 ######             #     ####    ####   ######     #       #    #
########################################################################
#########
# should be printed inside <head>..</head>
#
sub js_tooltip_header {
    return '<script language="javascript" src="/js/ztooltip.js"></script>';
}

#########
# should be printed just after <body>
#
sub js_tooltip_div {
    return '<div id="jstooldiv" style="position: absolute;visibility: hidden;"></div>';
}

#########
# args are [caption,] text
#
sub js_tooltip {
    my ($caption, $str) = @_;

    if(defined $str && $caption ne "") {
	return "onmouseover=\"ztooltip(\'$caption\',\'$str\');\" onmouseout=\"ztipoff();\"";
    } elsif(defined $str) {
	return "onmouseover=\"ztooltip(\'$str\');\" onmouseout=\"ztipoff();\"";
    } elsif(defined $caption) {
	return "onmouseover=\"ztooltip(\'$caption\');\" onmouseout=\"ztipoff();\"";
    } else {
	return "";
    }
}

#########
#
#
sub js_init{
  return qq(
<script language="javascript">
<!-- Hide script
function init()  {  
  if(document.feederform) {
    document.feederform.q.focus();
    document.feederform.q.select();
  }
  return (false);
}
  preloaders = new Array;
  preloaders[0] = new Image(1,1);
  preloaders[0].src = "/gfx/blank.gif";
  preloaders[1] = new Image(112,195);
  preloaders[1].src = "/gfx/gray.gif";
  preloaders[2] = new Image(112,195);
  preloaders[2].src = "/gfx/green.gif";
  preloaders[3] = new Image(16,16);
  preloaders[3].src = "/gfx/close.gif";
// End script hiding -->
</script>);
}

1;
__END__

=head1 NAME

    JSTools - Provides customised javascript hooks for Ensembl.

=head1 SYNOPSIS

    use JSTools;
    # in <head>..</head>
    print js_tooltip_header();   # to use tooltips
    print js_menu_header();      # to use menus

    # at the top of <body>..</body>
    print js_tooltip_div();      # to use tooltips
    print js_menu_div();         # to use menus

    # to use popups
    print js_popup('/Docs/index.html');
    print js_popup('/Docs/index.html','popup_target');
    print js_popup('/Docs/index.html','popup_target','width=450,height=600,resizable=yes,toolbar=no,scrollbars=yes,location=no');

    # to use tooltips
    my $tip = &JSTools::js_tooltip('optional caption', 'tooltip text');
    print "<a href=\"http://yackyack.com/\" $tip>";
    
    # to use menus
    my %menuopts = (
	'caption' => 'menu caption',
	'link x'  => '/perl/x',
	'link y'  => '/perl/y',
	'link z'  => '/perl/z',
    );

    my $menutxt = &JSTools::js_menu(\%menuopts);
    print "<a href=\"$menutxt\">";

    # to use popups
    my $popup = &JSTools::js_popup('url', 'optional target', 'optional window attributes');

=head1 EXPORTS

    js_popup
    js_tooltip_header js_tooltip_div js_tooltip
    js_menu_header js_menu_div js_menu

=head1 DESCRIPTION
    JSTools provides methods for producing javascript popup windows and layered tooltips and menus

=head1 AUTHOR - Roger Pettett, rmp@sanger.ac.uk

=head1 SEE ALSO
    htdocs/js/ztooltip.js
    htdocs/js/zmenu.js
=cut
