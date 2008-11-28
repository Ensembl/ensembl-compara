package EnsEMBL::Web::Component::UniSearch::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  if ($object->param('q')) {
    $html = qq(<h2>Search Results</h2>);

    foreach my $search_index ( sort keys %{$object->Obj->{'results'} } ) {
      my( $results, $count ) = @{ $object->Obj->{'results'}{$search_index} };
      $html .= "<h3>Search results for $search_index</h3><p>$count entries matched your search strings.</p><ol>";
      foreach my $result ( @$results ) {
        $html .= sprintf(qq(<li><strong>%s:</strong> <a href="%s">%s</a>),
          $result->{'subtype'}, $result->{'URL'}, $result->{'ID'}
        );
        if( $result->{'URL_extra'} ) {
          foreach my $E ( @{[$result->{'URL_extra'}]} ) {
            $html .= sprintf(qq( [<a href="%s" title="%s">%s</a>]),
              $E->[2], $E->[1], $E->[0]
            );
          }
        }
        if( $result->{'desc'} ) {
          $html .= sprintf(qq(<br />%s), $result->{'desc'});
        }
        $html .= '</li>';
      }
      $html .= '</ol>';
    }
  }
  else {
    my $species = $object->species || '';
    my $dir = $species ? '/'.$species : '';

    my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
    my $sp_name = $object->species_defs->SPECIES_COMMON_NAME || '';
    $html = qq(<h3>Search $sitename $sp_name</h3>);

    my $form = EnsEMBL::Web::Form->new( 'unisearch', "$dir/UniSearch/Summary", 'get' );

    $form->add_element(
      'type'    => 'String',
      'name'    => 'q',
      'label'   => 'Search for',
    );

    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'species',
      'value' => $species,
    );

    $form->add_element(
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Go',
    );

    $html .= $form->render;
  }

  return $html;
}

1;
