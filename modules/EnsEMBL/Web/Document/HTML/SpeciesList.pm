# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my ($class, $hub) = @_;
  
  my $self = $class->SUPER::new(
    species_defs => $hub->species_defs,
    user         => $hub->user,
    favourites   => $hub->get_favourite_species
  );
  
  bless $self, $class;
  
  $self->{'species_info'} = $self->set_species_info;
  
  return $self;
}

sub user         { return $_[0]{'user'};         }
sub species_info { return $_[0]{'species_info'}; }
sub favourites   { return $_[0]{'favourites'};   }

sub set_species_info {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  if (!$self->{'species_info'}) {
    my $species_info = {};

    foreach ($species_defs->valid_species) {
      $species_info->{$_} = {
        key        => $_,
        name       => $species_defs->get_config($_, 'SPECIES_BIO_NAME'),
        common     => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
        scientific => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
        group      => $species_defs->get_config($_, 'SPECIES_GROUP'),
      };
    }

    # give the possibility to add extra info to $species_info via the function
    $self->modify_species_info($species_info);
    
    $self->{'species_info'} = $species_info;
  }
  
  return $self->{'species_info'};
}

sub modify_species_info {}

sub render {
  my $self      = shift;
  my $species_defs = $self->species_defs;
  my $sitename     = $species_defs->ENSEMBL_SITETYPE;
  my $species_info = $self->species_info;
  my $labels       = $species_defs->TAXON_LABEL; ## sort out labels
  my $favourites   = $self->favourites;
  my (@group_order, %label_check);
  
  my $html = '<div class="static_all_species">
  <form action="#">
    <h3 class="box-header">All genomes</h3>
    <div style="margin-top:8px;">
    <select name="species" class="dropdown_redirect">
      <option value="/">-- Select a species --</option>
  ';
  
  if (scalar @$favourites) {
    $html .= qq{<optgroup label="Favourite species">\n};
    $html .= sprintf qq{<option value="%s/Info/Index">%s</option>\n}, encode_entities($_->{'key'}), encode_entities($_->{'common'}) for map $species_info->{$_}, @$favourites;
    $html .= "</optgroup>\n";
  }
  
  foreach my $taxon (@{$species_defs->TAXON_ORDER || []}) {
    my $label = $labels->{$taxon} || $taxon;
    push @group_order, $label unless $label_check{$label}++;
  }

  ## Sort species into desired groups
  my %phylo_tree;
  
  foreach (values %$species_info) {
    my $group = $_->{'group'} ? $labels->{$_->{'group'}} || $_->{'group'} : 'no_group';
    push @{$phylo_tree{$group}}, $_;
  }  

  ## Output in taxonomic groups, ordered by common name  
  foreach my $group_name (@group_order) {
    my $optgroup     = 0;
    my $species_list = $phylo_tree{$group_name};
    my @sorted_by_common;
    
    if ($species_list && ref $species_list eq 'ARRAY' && scalar @$species_list) {
      if ($group_name eq 'no_group') {
        if (scalar @group_order) {
          $html    .= qq{<optgroup label="Other species">\n};
          $optgroup = 1;
        }
      } else {
        $html    .= sprintf qq{<optgroup label="%s">\n}, encode_entities($group_name);
        $optgroup = 1;
      }
      
      @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} } @$species_list;
    }
    
    $html .= sprintf qq{<option value="%s/Info/Index">%s</option>\n}, encode_entities($_->{'key'}), encode_entities($_->{'common'}) for @sorted_by_common;
    
    if ($optgroup) {
      $html    .= "</optgroup>\n";
      $optgroup = 0;
    }
  }

  $html .= qq{
        </select>
      </div>
    </form>
    <p><a href="/info/about/species.html">View full list of all $sitename species</a></p>
    </div>
  };
  
  return $html;
}

1;
