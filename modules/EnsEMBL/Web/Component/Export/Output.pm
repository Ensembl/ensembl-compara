=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Export::Output;

use strict;

use POSIX qw(floor);

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $custom_outputs;
  
  if($hub->function eq 'Location') {    
    $custom_outputs = {ld => sub { return $self->ld_dump; }};        
    return $self->builder->object('Export')->process($custom_outputs);  #the reason to call the object like this is because the hub type is not export (change in Controller/Export).
   } elsif ($hub->function eq 'Transcript'){
      $custom_outputs = { gen_var => sub { return $self->genetic_variation; } };
      return $self->builder->object('Export')->process($custom_outputs);
   } else {
    return $self->builder->object('Export')->process();
  }
  
}

sub ld_dump {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->builder->object('Export');
  my $v      = $hub->param('v');

  my %pop_params = map { $hub->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $hub->param;    
  warn 'ERROR: No population defined' and return unless %pop_params;

  foreach (values %pop_params) { 
    my $pop_param       = $hub->param("pop$_");
    $pop_param          = $object->get_pop_name($pop_param);
    my @colour_gradient = ('ffffff', $hub->colourmap->build_linear_gradient(41, 'mistyrose', 'pink', 'indianred2', 'red'));
    my $ld_values       = $object->get_ld_values($pop_param, $v);
    
    my %populations     = map { $_ => 1 } map { keys %$_ } values %$ld_values;
  
    my $header_style = 'background-color:#CCCCCC;font-weight:bold;';
 
    foreach my $pop_name (sort { $a cmp $b } keys %populations) {
      foreach my $ld_type (keys %$ld_values) {
        my $ld = $ld_values->{$ld_type}->{$pop_name};
        
        next unless $ld->{'data'};
      
        my ($starts, $snps, $data) = (@{$ld->{'data'}});
        my $table = $object->html_format ? $self->new_table : undef;
      
        unshift (@$data, []);
      
        $object->html("<h3>$ld->{'text'}</h3>");
      
        if ($table) {
          $table->add_option('cellspacing', 2);
          $table->add_option('rows', '', ''); # No row colouring
          $table->add_columns(map {{ title => $_, align => 'center' }} ( 'bp&nbsp;position', 'SNP', @$snps ));
        } else {
          $object->html('=' x length $ld->{'text'});
          $object->html('');
          $object->html(join "\t", 'bp position', 'SNP', @$snps);
        }
      
        foreach my $row (@$data) {
          next unless ref $row eq 'ARRAY';
        
          my $snp = shift @$snps;
          my $pos = shift @$starts;

          if ($table) {
            $snp =~ s/\*//g;
            my $url = $hub->url({
                        type   => 'Variation',
                        action => 'Explore',
                        v      => $snp
                      });
            $pos = qq{<span style="font-weight:bold">$pos</span>} if ($snp eq $v);
            $snp = ($snp eq $v) ? qq{<span class="_ht ld_focus_variant" title="Focus variant">$snp</span>}  : qq{<a href="$url">$snp</a>};
          }

          my @values;
          foreach my $r (@$row) {
            my $value = '-';
            $value = sprintf('%.3f',$r) if $r;
            push @values,{
              value => $value,
              style => "background-color:#".($r eq '-'?'ffffff':$colour_gradient[floor($r*40)]),
            };
          }

          my @row_style = map { 'background-color:#' . ($_ eq '-' ? 'ffffff' : $colour_gradient[floor($_*40)]) . ';' } @values;

          if ($table) {
            $table->add_row([ $pos, $snp, @values, $snp ]);
            $table->add_option('row_style', [ $header_style, $header_style, @row_style, $header_style ]);
          } else {
            $object->html(join "\t", $pos, $snp, @values, $snp);
          }
        }
      
        $object->html($table ? $table->render : '');
      }
    }
  }
}

sub genetic_variation {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->builder->object('Export');
  
  my $params;
  map { /opt_pop_(.+)/; $params->{$1} = 1 if $hub->param($_) ne 'off' } grep { /opt_pop_/ } $hub->param;
  
  my @samples  = $object->get_samples(undef, $params);
  my $snp_data = $object->get_genetic_variations(@samples);
  
  $object->html(sprintf '<h2>Variant data for strains on transcript %s</h2>', $object->stable_id);
  $object->html('<p>Format: tab separated per strain (SNP id; Type; Amino acid change;)</p>');
  $object->html('');
  
  my $colours    = $hub->species_defs->colour('variation');
  my $colour_map = $hub->colourmap;
  my $table      = $object->html_format ? $self->new_table : undef;
  
  if ($table) {
    $table->add_option('cellspacing', 2);
    $table->add_columns(map {{ title => $_, align => 'left' }} ( 'bp&nbsp;position', @samples ));
  } else {
    $object->html(join "\t", 'bp position', @samples);
  }
  
  foreach my $snp_pos (sort keys %$snp_data) {
    my @info      = ($snp_pos);
    my @row_style = ('');
    
    foreach my $sample (@samples) {
      if ($snp_data->{$snp_pos}->{$sample}) {
        foreach my $row (@{$snp_data->{$snp_pos}->{$sample}}) {
          (my $type = $row->{'consequence'}) =~ s/\(Same As Ref. Assembly\)//;
          
          my $colour = $row->{'aachange'} eq '-' ? '' : $colour_map->hex_by_name($colours->{lc $type}->{'default'});
          
          push @info, "$row->{'ID'}; $type; $row->{'aachange'};";
          push @row_style, $colour ? "background-color:$colour" : '';
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
      $object->html(join "\t", @info);
    }
  }
  
  $object->html($table->render) if $table;
}


1;
