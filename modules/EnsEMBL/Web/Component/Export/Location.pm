package EnsEMBL::Web::Component::Export::Location;
use strict;

use POSIX qw(floor);

use EnsEMBL::Web::Document::SpreadSheet;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  
  my $custom_outputs = {
    ld => sub { return $self->ld_dump; }
  };
  
  return $self->export($custom_outputs);
}

sub ld_dump {
  my $self = shift;
  my $object = $self->object;
    
  my $format = $object->param('_format');
  my $pop_param = $object->param('opt_pop');
  my $zoom = 20000; # Currently non-configurable
  
  warn 'ERROR: No population defined' and return unless $pop_param;
  
  my @colour_gradient = ('ffffff', $object->image_config_hash('ldview')->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));
  
  my $ld_values = $object->get_ld_values($pop_param, $object->param('v'), $zoom);
  
  my $populations = {};
  map { $populations->{$_} = 1 } map { keys %{$ld_values->{$_}} } keys %$ld_values;
  
  my $header_style = 'background-color:#CCCCCC;font-weight:bold;';
  my ($table, $text, $html);
  
  foreach my $pop_name (sort { $a cmp $b } keys %$populations) {
    my $flag = 1;

    foreach my $ld_type (keys %$ld_values) {      
      next unless $ld_values->{$ld_type}{$pop_name}{'data'};
      
      my ($starts, $snps, $data) = (@{$ld_values->{$ld_type}{$pop_name}{'data'}});
      
      unshift (@$data, []);
      
      if ($format eq 'Text') {
        $text = join ("\t", 'bp position', 'SNP', @$snps) . "\n";
      } else {
        $table = new EnsEMBL::Web::Document::SpreadSheet;
        
        $table->add_option('cellspacing', 2);
        $table->add_option('rows', '', ''); # No row colouring
        $table->add_columns(map {{ title => $_, align => 'center' }} ( 'bp&nbsp;position', 'SNP', @$snps ));
      }
      
      foreach my $row (@$data) {
        next unless ref $row eq 'ARRAY';
        
        my $snp = shift @$snps;
        my $pos = shift @$starts;
        
        my @ld_values = map { $_ ? sprintf("%.3f", $_) : '-' } @$row;
        my @row_style = map { 'background-color:#' . ($_ eq '-' ? 'ffffff' : $colour_gradient[floor($_*40)]) . ';' } @ld_values;
        
        if ($format eq 'Text') {
          $text .= join ("\t", $pos, $snp, @ld_values, $snp) . "\n";
        } else {
          $table->add_row([ $pos, $snp, @ld_values, $snp ]);
          $table->add_option('row_style', [ $header_style, $header_style, @row_style, $header_style ]);
        }
      }
      
      if ($format eq 'Text') {
        $html .= "$ld_values->{$ld_type}{$pop_name}->{'text'}\n";
        $html .= ('=' x length $ld_values->{$ld_type}{$pop_name}->{'text'}) . "\n\n";
        $html .= "$text\n";
      } else {
        $html .= "<h3>$ld_values->{$ld_type}{$pop_name}->{'text'}</h3>";
        $html .= $table->render;
      }
    }
  }

  return $html;
}

1;
