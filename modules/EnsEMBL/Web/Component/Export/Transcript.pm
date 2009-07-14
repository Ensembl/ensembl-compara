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
  
  my $transcript_id = $object->stable_id;
  my $format = $object->param('_format');
  
  my $params;
  map { /opt_pop_(.+)/; $params->{$1} = 1 if $object->param($_) ne 'off' } grep { /opt_pop_/ } $object->param;
  
  my @samples = $object->get_samples(undef, $params);
  my $snp_data = $object->get_genetic_variations(@samples);
  
  my $header = qq{
    <h2>Variation data for strains on transcript $transcript_id</h2>
    <p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>
  };
  
  my $colours = $object->species_defs->colour('variation');
  my $colour_map = $object->get_session->colourmap;
  
  my ($html, $table, $text);
  
  if ($format eq 'Text') {
    $text = join "\t", 'bp position', @samples, "\r\n";
  } else {
    $table = new EnsEMBL::Web::Document::SpreadSheet;
    
    $table->add_option('cellspacing', 2);
    $table->add_columns(map {{ title => $_, align => 'left' }} ( 'bp&nbsp;position', @samples ));
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
    
    if ($format eq 'Text') {
      $text .= join "\t", @info, "\r\n";
    } else {
      $table->add_row(\@info);
      $table->add_option('row_style', \@row_style);
    }
  }
  
  if ($format eq 'Text') {
    $html = "$text\r\n";
    $html =~ s/<.*?>//g; # Strip html tags
  } else {
    $html = $table->render;
  }
  
  $html ||= 'No data available';
  
  return $header . $html;
}

1;
