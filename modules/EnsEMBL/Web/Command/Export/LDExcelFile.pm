package EnsEMBL::Web::Command::Export::LDExcelFile;

use strict;

use Class::Std;
use POSIX qw(floor);

use EnsEMBL::Web::Document::Renderer::Excel;
use EnsEMBL::Web::TmpFile::Text;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  
  my $url = sprintf '/%s/Export/LDFormats/%s', $object->species, $object->function;
  
  my $params = { type => 'excel', excel_file => $self->make_file };
  map { $params->{$_} = $object->param($_) } $object->param;
  
  $self->ajax_redirect($url, $params);
}

sub make_file {
  my $self = shift;
  my $object = $self->object;
  
  my $params = $object->parent->{'params'};
  my $pop_param = $params->{'opt_pop'}->[0];
  my $zoom = 20000; # Currently non-configurable
  
  warn 'ERROR: No population defined' and return unless $pop_param;
  
  my @colour_gradient = ('ffffff', $object->image_config_hash('ldview')->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));
  
  my $ld_values = $object->get_ld_values($pop_param, $params->{'v'}->[0], $zoom);
  
  my $populations = {};
  map { $populations->{$_} = 1 } map { keys %{$ld_values->{$_}} } keys %$ld_values;
  
  my $file = new EnsEMBL::Web::TmpFile::Text(extension => 'xls', prefix => '');
  my $renderer = new EnsEMBL::Web::Document::Renderer::Excel({ fh => $file });
  my $table = $renderer->new_table_renderer;
  
  foreach my $pop_name (sort { $a cmp $b } keys %$populations) {
    my $flag = 1;
    
    foreach my $ld_type (keys %$ld_values) {
      next unless $ld_values->{$ld_type}{$pop_name}{'data'};
      
      my ($starts, $snps, $data) = (@{$ld_values->{$ld_type}{$pop_name}{'data'}});
      
      unshift @$data, [];
      
      (my $sheet_name = $pop_name) =~ s/[^\w\s]/_/g;
      
      if ($flag) {
        $table->new_sheet($sheet_name); # Start a new sheet(and new table)
        $flag = 0;
      } else {
        $table->new_table; # Start a new table
      }
      
      $table->set_width(2 + @$snps);
      $table->heading($ld_values->{$ld_type}{$pop_name}{'text'});
      $table->new_row;
      
      $table->write_header_cell('bp position');
      $table->write_header_cell('SNP');
      
      $table->write_header_cell($_) for @$snps;
      $table->new_row;
      
      foreach my $row (@$data) {
        next unless ref $row eq 'ARRAY';
        
        my $snp = shift @$snps;
        my $pos = shift @$starts;
        
        my @values = map { $_ ? sprintf("%.3f", $_) : '-' } @$row;
        my @row_style = map { 'background-color:#' . ($_ eq '-' ? 'ffffff' : $colour_gradient[floor($_*40)]) . ';' } @values;
        
        $table->write_header_cell($pos);
        $table->write_header_cell($snp);
        
        foreach my $value (@values) {
          my $format = $table->new_format({
            align   => 'center',
            bgcolor => $value eq '-' ? 'ffffff' : $colour_gradient[floor($value*40)]
          });
          
          $table->write_cell($value, $format);
        }
        
        $table->write_header_cell($snp);
        $table->new_row;
      }
    }
  }
  
  $renderer->close;
  $file->save;
  
  return $file->URL;
}


}

1;
