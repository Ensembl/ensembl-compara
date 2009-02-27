package EnsEMBL::Web::Document::HTML::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;
                                                                                
our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new {
  return shift->SUPER::new(
    '_default'  => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEFAULT_SEARCHCODE || 'ensembl',
  );
}

sub default_search_code { my $self = shift; return $self->{'_default'}; }

sub search_url {
    my $species = $_[0]->home_url.$EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_species;
    $species =~ s/^\/$//;
    return $species ? "$species/psychic" : '/common/psychic';
}

sub add_index { push @{$_[0]->{'indexes'}}, $_[1]; }

sub render {
  my $self   = shift;
  my $i_url = $self->img_url;
  $self->printf( '
        <form action="%s">
          <table id="se" class="print_hide" summary="layout table">
            <tr>
              <td id="se_but"><img id="se_im" src="%ssearch/%s.gif" alt="" /><input type="hidden" id="se_si" name="site" value="%s" /><img src="%ssearch/down.gif" style="width:7px" alt="" /></td>
              <td><label class="hidden" for="se_q">Search terms</label><input id="se_q" type="text" name="q" /></td>
              <td id="se_b"><input type="image" src="%ssearch/mag.gif" alt="Search&gt;&gt;" /></td>
            </tr>
          </table>
        </form>',
    $self->search_url,
    $i_url, lc($self->default_search_code),
    $self->default_search_code,
    $i_url, 
    $i_url
  );
}

1;
