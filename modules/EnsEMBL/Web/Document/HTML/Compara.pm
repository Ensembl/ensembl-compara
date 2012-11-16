package EnsEMBL::Web::Document::HTML::Compara;

## Provides content for compara documeentation - see /info/docs/compara/analyses.html
## Base class - does not itself output content

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub sci_name {
  my ($self, $name) = @_;
  $name = ucfirst($name);
  $name =~ s/_/ /;
  return $name;
}

sub common_name {
  my ($self, $name) = @_;
  $name = ucfirst($name);
  return $self->hub->species_defs->get_config($name, 'SPECIES_COMMON_NAME');
}

## Output a list of aligned species
sub format_list {
  my ($self, $method, $list) = @_;
  my $hub = $self->hub; 
  my $html;

  if ($list && scalar(@{$list||[]})) {
    foreach (@$list) {
      my $species_info = $self->_mlss_species_info($hub, $method, $_->{'name'});

      if ($species_info && scalar(@{$species_info||[]})) {
        my $count = scalar(@$species_info);
        $html .= sprintf '<h3>%s %s %s</h3>
              <p><b>(method_link_type="%s" : species_set_name="%s")</b></p>',
              $count, $_->{'label'}, $method, $method, $_->{'name'};

        $html .= '<ul>';
        foreach my $sp (@$species_info) {
          $html .= sprintf '<li>%s (%s)</li>', $sp->{'common_name'}, $sp->{'name'};
        }
        $html .= '</ul>';
      }
    }
  }

  return $html;
}

## Fetch names of a set of aligned species
sub _mlss_species_info {
  my ($self, $hub, $method, $set_name) = @_;
  my $info = [];

  my $compara_db = $hub->database('compara');
  if ($compara_db) {
    my $mlss_adaptor  = $compara_db->get_adaptor('MethodLinkSpeciesSet');
    my $mlss          = $mlss_adaptor->fetch_by_method_link_type_species_set_name($method, $set_name);
    my $species_set   = $mlss->species_set_obj;
    my $genome_dbs    = $species_set->genome_dbs;

    foreach my $db (@{$genome_dbs||[]}) {
      my $name    = ucfirst($db->name);
      my $common  = $hub->species_defs->get_config($name, 'SPECIES_COMMON_NAME');
      $name =~ s/_/ /g;

      push @$info, {'name' => $name, 'common_name' => $common};
    }
  }

  my @sorted = sort {$a->{'common_name'} cmp $b->{'common_name'}} @$info;

  return \@sorted;
}

1;
