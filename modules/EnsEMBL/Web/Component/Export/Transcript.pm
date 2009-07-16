package EnsEMBL::Web::Component::Export::Transcript;

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $custom_outputs = {
    gen_var => sub { return $self->genetic_variation; }
  };
  
  return $self->export($custom_outputs, [ $object ]);
}


sub genetic_variation {
  my $self = shift;
  my $object = $self->object;
  
  my $params;
  map { /opt_pop_(.+)/; $params->{$1} = 1 if $object->param($_) ne 'off' } grep { /opt_pop_/ } $object->param;
  
  my @samples = $object->get_samples(undef, $params);
  my $snp_data = $object->get_genetic_variations(@samples);
  
  $self->html(sprintf '<h2>Variation data for strains on transcript %s</h2>', $object->stable_id);
  $self->html('<p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>');
  $self->html('');
  
  my $colours = $object->species_defs->colour('variation');
  my $colour_map = $object->get_session->colourmap;
  
  my $table = new EnsEMBL::Web::Document::SpreadSheet if $self->html_format;
  
  if ($table) {
    $table->add_option('cellspacing', 2);
    $table->add_columns(map {{ title => $_, align => 'left' }} ( 'bp&nbsp;position', @samples ));
  } else {
    $self->html(join "\t", 'bp position', @samples);
  }
  
  foreach my $snp_pos (sort keys %$snp_data) {
    my @info = ($snp_pos);
    my @row_style = ('');
    
    foreach my $sample (@samples) {
      if ($snp_data->{$snp_pos}->{$sample}) {
        foreach my $row (@{$snp_data->{$snp_pos}->{$sample}}) {
          (my $type = $row->{'consequence'}) =~ s/\(Same As Ref. Assembly\)//;
          
          my $colour = $row->{'aachange'} eq '-' ? '' : $colour_map->hex_by_name($colours->{lc $type}->{'default'});
          
          push @info, "$row->{'ID'}; $type; $row->{'aachange'};";
          push @row_style, $colour ? "background-color:#$colour" : '';
        }
      } else {
        push @info, '';
        push @row_style, '';
      }
    }
    
    if ($table) {
      $table->add_row(\@info);
      $table->add_option('row_style', \@row_style);
    } else {
      $self->html(join "\t", @info);
    }
  }
  
  $self->html($table->render) if $table;
}

1;
