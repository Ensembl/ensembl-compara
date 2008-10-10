package EnsEMBL::Web::ViewConfig::Location::Align;

use strict;
use warnings;
no warnings 'uninitialized';
no strict 'refs';

sub init {
  my( $view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_top      yes 
    panel_zoom      no
    zoom_width     100
    context     100000
  ));
  my @multiple = ();
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};

  foreach my $row_key (
    grep { $hash->{$_}{'class'} !~ /pairwise/ }
    keys %$hash
  ) {
    warn "VC:  $row_key: ",join "; ", keys %{$hash->{$row_key}{'species'}};
    $view_config->_set_defaults( map { ( lc("species_$row_key"."_$_"), 'yes') } keys %{ $hash->{$row_key}{'species'} } );
  }
  $view_config->storable = 1;
  $view_config->add_image_configs({qw(
    alignsliceviewtop    nodas
    alignsliceviewbottom nodas
  )});
}

sub form {
  my( $view_config, $object ) = @_;

  $view_config->add_form_element({ 'type' => 'YesNo', 'name' => 'panel_top',  'select' => 'select', 'label'  => 'Show overview panel' });
 
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
  my $species = $view_config->species;

warn "FORM ",keys %$hash;
  foreach my $row_key (
#    sort { scalar(@{$hash->{$a}{'species'}})<=> scalar(@{$hash->{$b}{'species'}}) }
    grep { $hash->{$_}{'class'} !~ /pairwise/ }
    keys %$hash
  ) {
warn "ROW $row_key";
    my $row = $hash->{$row_key};
    next unless $row->{'species'}{$species};
    $view_config->add_fieldset( "Options for ".$row->{'name'} );
    foreach( sort keys %{$row->{'species'}} ) {
      my $name = 'species_'.$row_key.'_'.lc($_);
      if( $_ eq $species ) {
        $view_config->add_form_element({
          'type'     => 'Hidden',   'name' => $name
        });
      } else {
        $view_config->add_form_element({
          'type'     => 'CheckBox', 'label' => $view_config->_species_label($_),
          'name'     => $name,
          'value'    => 'yes', 'raw' => 1
        });
     }
    } 
  }
    
}
1;
