# $Id$

package EnsEMBL::Web::Document::HTML::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::RegObj;
                                                                                
use base qw(EnsEMBL::Web::Document::HTML);

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
  my $search_url = $self->search_url;
  
  my @options = (
    [ 'ensembl_all', 'Ensembl search all species' ],
    $search_url =~ m!/common/psychic! ? [ 'ensembl', 'Ensembl search' ] : [ 'ensembl', 'Ensembl search this species' ],
    [ 'vega', 'Vega search' ],
    [ 'ebi', 'EBI search' ],
    [ 'sanger', 'Sanger search' ]
  );
  
  my $search_options;
  $search_options .= qq{<dt id="se_$_->[0]"><img src="/i/search/$_->[0].gif" alt="$_->[1]"/>$_->[1]</dt>\n} for @options;
  
  $self->printf( '
      <div id="searchPanel" class="js_panel">
        <input type="hidden" class="panel_type" value="SearchBox" />
        <form action="%s">
          <table class="search print_hide" summary="layout table">
            <tr>
              <td class="sites button"><img class="search_image" src="%ssearch/%s.gif" alt="" /><img src="%ssearch/down.gif" style="width:7px" alt="" /><input type="hidden" name="site" value="%s" /></td>
              <td><label class="hidden" for="se_q">Search terms</label><input id="se_q" type="text" name="q" /></td>
              <td class="button"><input type="image" src="%ssearch/mag.gif" alt="Search&gt;&gt;" /></td>
            </tr>
          </table>
          <dl class="site_menu" style="display: none">
            %s
          </dl>
        </form>
      </div>',
    $search_url,
    $i_url, 
    lc($self->default_search_code),
    $i_url,
    $self->default_search_code,
    $i_url,
    $search_options
  );
}


1;


