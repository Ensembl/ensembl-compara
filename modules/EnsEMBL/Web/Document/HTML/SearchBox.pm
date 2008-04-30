package EnsEMBL::Web::Document::HTML::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;
                                                                                
our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new {
  return shift->SUPER::new(
    '_home_url' => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT,
    '_img_url'  => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_IMAGE_ROOT,
    '_default'  => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEFAULT_SEARCHCODE,
  );
}

sub img_url  { return $_[0]{'_img_url'};   }
sub home_url { return $_[0]{'_home_url'};  }
sub default_search_code { return $_[0]{'_default'}; }
sub search_url { return $_[0]->home_url.$EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_species.'/Search'; }

sub add_index { push @{$_[0]->{'indexes'}}, $_[1]; }

sub render {
  my $self   = shift;
  $self->printf( '
<form action="%s">
  <input type="hidden" id="se_si" name="site" value="%s" />
  <table id="se">
    <tr>
      <td id="se_but"><img id="se_im" src="%ssearch/%s.gif" alt="" /><img src="%ssearch/down.gif" style="width:7px" alt="" /></td>
      <td><input id="se_q" type="text" name="q" /></td>
      <td id="se_b"><input type="submit" value="Search&gt;&gt;" /></td>
    </tr>
  </table>
  <dl style="display: none" id="se_mn"></dl>
</form>
',
    $self->search_url, $self->default_search_code,
    $self->img_url, lc($self->default_search_code), $self->img_url
  );
}

1;
