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

package EnsEMBL::Web::Component::LRG::LRGDiff;

### NAME: EnsEMBL::Web::Component::LRG::LRGDiff;
### Generates a table of differences between the LRG and the reference sequence

### STATUS: Under development

### DESCRIPTION:
### Because the LRG page is a composite of different domain object views, 
### the contents of this component vary depending on the object generated
### by the factory

use strict;
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);
use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub; 
  my $lrg  = $self->object->Obj;
  my $lrg_feature_slice = $lrg->feature_Slice;
  my $slice_adaptor = $hub->get_adaptor('get_SliceAdaptor');
  my $vf_adaptor = $hub->database('variation')->get_VariationFeatureAdaptor; 
  my $html;
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Location'                                                   },
    { key => 'show',     sort => 'none',          title => ''                                                           },
    { key => 'type',     sort => 'string',        title => 'Type'                  , help => 'from the Reference'       },
    { key => 'lrg' ,     sort => 'string',        title => 'LRG sequence'                                               },
    { key => 'ref',      sort => 'string',        title => 'Reference sequence'                                         },
    { key => 'var',      sort => 'string',        title => 'Matching variant(s)'                                        },
    { key => 'maf',      sort => 'none',          title => 'Minor allele frequency', help => 'Frequency (Minor Allele)' },
  ];
  
  my @rows;
 
  foreach my $diff (@{$lrg->get_all_differences}) {
		
    my $align_link .= '#'.$diff->{start};
    my $align_page = qq{<a href="$align_link">[Show in alignment]</a>};

    my @var_list;
    my @maf_list;

    my $seq_start = ($diff->{'start'} < $diff->{'end'}) ? $diff->{'start'} : $diff->{'end'};
    my $seq_end = ($diff->{'start'} < $diff->{'end'}) ? $diff->{'end'} : $diff->{'start'};
    my $seq_ref = $diff->{'ref'};

    my $diff_slice = $lrg->sub_Slice($seq_start,$seq_end);

    # Deletion of more than 1 nucleotide
    if ($diff->{'type'} eq 'deletion' and length($diff->{'ref'}) > 1) {;
      $diff->{'ref'} =~ /^(\w+)\s+(\d+)-(\d+)$/;
      my $ref_seq = $1;
      my $ref_start = $2;
      my $ref_end   = $3;

      if ($ref_seq && $ref_start && $ref_end) {
         $diff_slice = $slice_adaptor->fetch_by_region($lrg_feature_slice->coord_system_name,$lrg_feature_slice->seq_region_name,$ref_start,$ref_end);
         $seq_start = $ref_start;
         $seq_end   = $ref_end;
         $seq_ref   = $ref_seq;
      }
    }
    # Insertion of more than 1 nucleotide
    elsif ($diff->{'type'} eq 'insertion' and length($diff->{'seq'}) > 1) {
      my $ref_slice = $diff_slice->feature_Slice();
      my $ref_start = $ref_slice->start+$seq_start-1; # Inversion start/end for variant insertion
      my $ref_end = $ref_start-1;                     # Inversion start/end for variant insertion
      $diff_slice = $slice_adaptor->fetch_by_region($ref_slice->coord_system_name,$ref_slice->seq_region_name,$ref_end,$ref_start);
      $seq_start = $ref_start;
      $seq_end   = $ref_end;
    }

    my $vfs = ($diff_slice) ? $vf_adaptor->fetch_all_by_Slice($diff_slice) : [];
    
    foreach my $vf (@$vfs) {
      if ($vf->seq_region_start == $seq_start && $vf->seq_region_end == $seq_end) {
        my @v_alleles  = split('/',$vf->allele_string);
        if (scalar(@v_alleles) > 1) {
          my $ref_allele = shift(@v_alleles);
          reverse_comp(\$ref_allele) if ($vf->seq_region_strand == -1);
          my $lrg_match_found = 0;
          my $ref_match_found = 0;
          if ($ref_allele eq $seq_ref) {
            $ref_match_found = 1;
            foreach my $al (@v_alleles) {
              reverse_comp(\$al) if ($vf->seq_region_strand == -1);
              $lrg_match_found = 1 if ($al eq $diff->{'seq'});
            }
          }
          if ($lrg_match_found == 1 && $ref_match_found == 1) {
            my $var_name = $vf->name;
            my $url = $hub->url({
              type   => 'Variation',
              action => 'Explore',
              vf     => $vf->dbID,
              v      => $var_name,
            });
            push(@var_list, qq{<a href="$url">$var_name</a>});

            # MAF
            my $maf = $vf->minor_allele_frequency;
            my $maf_allele = $vf->minor_allele;
            my $maf_value = ($maf_allele) ? "$maf ($maf_allele)" : '-';
            push(@maf_list, $maf_value);
          }
        }
      }
    }

    my $location = $lrg->seq_region_name.':g.';
    # Substitution
    if ($diff->{'type'} eq 'substitution') {
      $location .= $diff->{'start'};
      if (length($diff->{'seq'}) > 1) {
        $location .= '_'.$diff->{'end'}.'del'.$diff->{'seq'}.'ins'.$diff->{'ref'};
      }
      else {
        $location .= $diff->{'seq'}.'>'.$diff->{'ref'};
      }
    }
    # LRG insertion
    elsif ($diff->{'type'} eq 'deletion') {
      $diff->{'ref'} =~ /^(\w+)\s+/;
      my $ref_seq = $1;
      my $lrg_start = ($diff->{'start'} < $diff->{'end'}) ? $diff->{'start'} : $diff->{'end'};
      my $lrg_end   = ($diff->{'start'} < $diff->{'end'}) ? $diff->{'end'} : $diff->{'start'};
      
      $location .= $lrg_start.'_'.$lrg_end.'ins'.$ref_seq;
    }
    # LRG deletion
    elsif ($diff->{'type'} eq 'insertion') {
      if (length($diff->{'seq'}) > 1) {
        $location .= '_'.$diff->{'end'};
      }
      $location .= 'del'.$diff->{'seq'};
    }
    # Other
    else {
      $location = $lrg->seq_region_name.":$diff->{'start'}".($diff->{'end'} == $diff->{'start'} ? '' : "-$diff->{'end'}");
    }
		
    push @rows, {
      location => $location,
      show     => $align_page,
      type     => $diff->{'type'},
      lrg      => $diff->{'seq'},
      ref      => $diff->{'ref'},
      var      => (scalar(@var_list)) ? join(', ',@var_list) : '-',
      maf      => (scalar(@maf_list)) ? join(', ',@maf_list) : '-',
    };
  }
  
  if (@rows) {
    $html .= $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
  } else {
    # find the name of the reference assembly
    my $csa = $self->hub->get_adaptor('get_CoordSystemAdaptor');
    my $assembly = $csa->fetch_all->[0]->version;
      
    $html .= "<h3>No differences found - the LRG reference sequence is identical to the $assembly reference assembly sequence</h3>";
  }
  
  return $html;
}

1;
