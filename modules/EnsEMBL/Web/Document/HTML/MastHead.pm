package EnsEMBL::Web::Document::HTML::MastHead;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::MastHead::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'sp_bio' => '?? ??', 'sp_common' => '??', 'site_name' => '??',
                                    'logo_src' => '', 'logo_w' => 40, 'logo_h' => 40, 'sub_title' => undef ); }

sub site_name :lvalue { $_[0]{'site_name'}; }
sub species   :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_bio    :lvalue { $_[0]{'sp_bio'}=~s/ /_/g; $_[0]{'sp_bio'}; }
sub sp_common :lvalue { $_[0]{'sp_common'}=~s/_/ /g; $_[0]{'sp_common'}; }
sub logo_src  :lvalue { $_[0]{'logo_src'}; }
sub logo_w    :lvalue { $_[0]{'logo_w'};   }
sub logo_h    :lvalue { $_[0]{'logo_h'};   }
sub logo_href :lvalue { $_[0]{'logo_href'};   }
#sub logo_img  { return sprintf '<img src="%s" style="width: %dpx; height: %dpx; vertical-align:bottom; border:0px; padding-bottom:2px" alt="" title="Home" />',
                               $_[0]->logo_src, $_[0]->logo_w, $_[0]->logo_h ; }

sub logo_img {
  my $self=shift;
  return sprintf(
    '<img src="%se-ensembl.gif" alt="" title="Return to home page" />',
    $self->img_url
  );
}
> sub sub_title :lvalue { $_[0]{'sub_title'}; }
> sub sub_link   { return $_[0]->_root_url.$_[0]->species.'/'; }
> sub home_url   { return $_[0]->_root_url; }
> sub img_url    { return $ENSEMBL_WEB_REGISTRY->ROOT_URL.'t/'; }
> sub search_url { return $ENSEMBL_WEB_REGISTRY->ROOT_URL.$_[0]->species.'/Search'; }
> sub default_search_code { return 'ensembl'; }

sub render {
  my $self = shift;
  my $linked_title = '<h1><a class="mh_lnk" href="#">Human</a></h1>';
  $self->print( '<table id="mh">
  <tr>');
# Logo on LHS...
  $self->printf( '
    <td id="mh_lo" rowspan="2"><a href="%s">%s</a></td>',
    $self->home_url, $self->logo_img
  );
  if( $self->sub_title ) {
    $self->printf( '
    <td id="mh_tt" rowspan="2"><h1><a class="mh_lnk" href="%s">%s</a></h1></td>',
      $self->sub_link, $self->sub_title );
  }
  $self->printf( '
    <td id="mh_search" style="background-color:#fff9af">
<form action="%s">
  <input type="hidden" id="se_si" name="site" value="%s" />
  <table id="se">
    <tr>
      <td id="se_but"><img id="se_im" src="%s" alt="" /><img src="%ssearch/down.gif" style="width:7px" alt="" /></td>
      <td><input id="se_q" type="text" name="q" /></td>
      <td style="cursor: hand; cursor: pointer;"><input type="submit"  style="cursor: hand; cursor: pointer;margin:0px; border:0px;background-color:#fff;padding:1px 0.5em;font-size: 0.8em; font-weight: bold" value="Search&gt;&gt;" /></td>
    </tr>
  </table>
  <dl style="display: none" id="se_mn"></dl>
</form>
    </td>',
    $self->search_url,
    $self->default_search_code,
    $self->img_url.'search/'.$self->default_search_code.'.gif',
    $self->img_url
  );
  $self->print('
  </tr>');
  $self->print('
  <tr>
    <td id="mh_bar">
      <div id="mh_lnk">');
  $self->printf('
        <a href="%sBlast">BLAST</a> | <a href="%sbiomart">BioMart</a> &nbsp;|&nbsp;
        <a href="#" id="login" class="modal_link">Login</a> | <a href="#" class="modal_link">Register</a> &nbsp;|&nbsp;
        <a href="%s">Home</a> | <a href="#" id="sitemap" class="modal_link">Site map</a> | <a href="#" id="help" class="modal_link"><span>e<span>?</span></span> Help</a>',
    $self->home_url, $self->home_url, $self->home_url
  );
  $self-print('
      </div>
    </td>
  </tr>');
  $self->print( '
</table>
<div style="display:none" id="conf"></div>');

}

1;

