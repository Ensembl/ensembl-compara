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

package EnsEMBL::Web::Component::Location::ComparaGenomicAlignment;

use strict;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self                     = shift;
  my $object                   = $self->object;
  my $species_defs             = $object->species_defs;
  my $p_species                = $species_defs->SPECIES_PRODUCTION_NAME;
  my $s_species                = $species_defs->get_config($object->param('s1'), 'SPECIES_PRODUCTION_NAME');
  my($p_chr, $p_start, $p_end) = $object->param('r')  =~ /^(.+):(\d+)-(\d+)$/;
  my($s_chr, $s_start, $s_end) = $object->param('r1') =~ /^(.+):(\d+)-(\d+)$/;
  my $method                   = $object->param('method');
  my $compara_db               = $object->database('compara');
  my $dafa                     = $compara_db->get_DnaAlignFeatureAdaptor;
  my $disp_method              = $method;
  
  $disp_method =~ s/(B?)LASTZ_NET/$1LASTz net/g;
  $disp_method =~ s/TRANSLATED_BLAT_NET/Trans. BLAT net/g;
  
  my $html;
  my $features;
  
  eval {
    $features = $dafa->fetch_all_by_species_region($p_species, undef, $s_species, undef, $p_chr, $p_start, $p_end, $method);
  };
  
  my @objects;
  
  foreach my $f (@$features) {
    ## This IS the aligmnent of which we speak 
    push @objects, $f if $f->seqname eq $p_chr && $f->start == $p_start && $f->end == $p_end && $f->hseqname eq $s_chr && $f->hstart == $s_start && $f->hend == $s_end;
  }
  
  foreach my $align (@objects) {
    $html .= sprintf(
      '<h3>%s alignment between %s %s %s and %s %s %s</h3>',
      $disp_method, 
      $species_defs->get_config(ucfirst $align->species,  'SPECIES_SCIENTIFIC_NAME'), $align->slice->coord_system_name,  $align->seqname, # FIXME: ucfirst hack
      $species_defs->get_config(ucfirst $align->hspecies, 'SPECIES_SCIENTIFIC_NAME'), $align->hslice->coord_system_name, $align->hseqname # FIXME: ucfirst hack
    );

    my $blocksize = 60;
    my $reg       = "(.{1,$blocksize})";
    
    my ($ori,  $start,  $end)  = $align->strand  < 0 ? (-1, $align->end, $align->start)   : (1, $align->start, $align->end);
    my ($hori, $hstart, $hend) = $align->hstrand < 0 ? (-1, $align->hend, $align->hstart) : (1, $align->hstart, $align->hend);
    my ($seq, $hseq)           = @{$align->alignment_strings || []};
    
    $html .= '<pre>';
    
    while ($seq) {
      $seq =~ s/$reg//;
      
      my $part = $1;
      
      $hseq =~ s/$reg//;
      
      my $hpart = $1;
      
      $html .= sprintf "%9d %-60.60s %9d\n%9s ", $start, $part, $start + $ori * (length($part) - 1), ' ';
      
      my @BP = split //, $part;
      
      foreach(split //, ($part ^ $hpart)) {
        $html .=  ord $_ ? ' ' : $BP[0] ;
        shift @BP;
      }
      
      $html   .= sprintf "\n%9d %-60.60s %9d\n\n", $hstart, $hpart, $hstart + $hori * (length($hpart) - 1);
      $start  += $ori * $blocksize;
      $hstart += $hori * $blocksize;
    }
    
    $html .= '</pre>';
  }
  
  return $html;
}

1;
