# $Id$

package EnsEMBL::Web::Component::Export::Location;

use strict;

use POSIX qw(floor);

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self = shift;
  
  my $custom_outputs = {
    ld => sub { return $self->ld_dump; }
  };
  
  return $self->export($custom_outputs);
}

sub ld_dump {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $v      = $hub->param('v');

  my %pop_params = map { $hub->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $hub->param;    
  warn 'ERROR: No population defined' and return unless %pop_params;

  foreach (values %pop_params) {
    my $pop_param       = $hub->param("pop$_");
    my $zoom            = 20000; # Currently non-configurable
    my @colour_gradient = ('ffffff', $hub->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));
    my $ld_values       = $object->get_ld_values($pop_param, $v, $zoom);
    my %populations     = map { $_ => 1 } map { keys %$_ } values %$ld_values;
  
    my $header_style = 'background-color:#CCCCCC;font-weight:bold;';
  
    foreach my $pop_name (sort { $a cmp $b } keys %populations) {
      foreach my $ld_type (keys %$ld_values) {
        my $ld = $ld_values->{$ld_type}->{$pop_name};
        
        next unless $ld->{'data'};
      
        my ($starts, $snps, $data) = (@{$ld->{'data'}});
        my $table = $self->html_format ? $self->new_table : undef;
      
        unshift (@$data, []);
      
        $self->html("<h3>$ld->{'text'}</h3>");
      
        if ($table) {
          $table->add_option('cellspacing', 2);
          $table->add_option('rows', '', ''); # No row colouring
          $table->add_columns(map {{ title => $_, align => 'center' }} ( 'bp&nbsp;position', 'SNP', @$snps ));
        } else {
          $self->html('=' x length $ld->{'text'});
          $self->html('');
          $self->html(join "\t", 'bp position', 'SNP', @$snps);
        }
      
        foreach my $row (@$data) {
          next unless ref $row eq 'ARRAY';
        
          my $snp = shift @$snps;
          my $pos = shift @$starts;
        
          my @values = map { $_ ? sprintf '%.3f', $_ : '-' } @$row;
          my @row_style = map { 'background-color:#' . ($_ eq '-' ? 'ffffff' : $colour_gradient[floor($_*40)]) . ';' } @values;
        
          if ($table) {
            $table->add_row([ $pos, $snp, @values, $snp ]);
            $table->add_option('row_style', [ $header_style, $header_style, @row_style, $header_style ]);
          } else {
            $self->html(join "\t", $pos, $snp, @values, $snp);
          }
        }
      
        $self->html($table ? $table->render : '');
      }
    }
  }
}

1;
