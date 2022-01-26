=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Command::Export::LDExcelFile;

use strict;

use POSIX qw(floor);

use EnsEMBL::Web::Document::Renderer::Excel;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $hub    = $self->hub;
  my $url    = $hub->url({ action => 'LDFormats', function => $hub->function });
  my $params = { type => 'excel', excel_file => $self->make_file };
  
  $self->ajax_redirect($url, $params);
}

sub make_file {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  
  my $params     = $hub->referer->{'params'};
  my %pop_params = map { $hub->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $hub->param;
  
  warn 'ERROR: No population defined', return unless %pop_params;
  
  my $file     = EnsEMBL::Web::TmpFile::Text->new(extension => 'xls', prefix => ''); 
  my $renderer = EnsEMBL::Web::Document::Renderer::Excel->new($file); 
  my $table    = $renderer->new_table_renderer;
  
  my @colour_gradient = ('ffffff', $hub->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));
  
  foreach (values %pop_params){ 
    my $pop_param   = $hub->param('pop'.$_);
    $pop_param      = $object->get_pop_name($pop_param); 
    my $ld_values   = $object->get_ld_values($pop_param, $params->{'v'}->[0]);
    my $populations = {};
    
    map { $populations->{$_} = 1 } map { keys %{$ld_values->{$_}} } keys %$ld_values;
    
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
  }
  
  $renderer->close;
  $file->save;
  
  return $file->URL;
}

1;
