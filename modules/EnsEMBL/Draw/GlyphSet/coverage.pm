=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::coverage;

### Resequencing read coverage
### STATUS: REMOVE? Read coverage has been removed from the variation db

use strict;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

use base  qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my ($self) = @_;
  my $type            = $self->type;
  my $Config          = $self->{'config'};
  my $transcript      = $Config->{'transcript'}->{'transcript'};
  my @coverage_levels = sort { $a <=> $b } @{$Config->{'transcript'}->{'coverage_level'}};
  my $max_coverage    = $coverage_levels[-1];
  my $min_coverage    = $coverage_levels[0] || $coverage_levels[1];
  my $coverage_obj    = $Config->{'transcript'}->{'coverage_obj'};
 
  unless (@$coverage_obj && @coverage_levels) {
    $self->push($self->Space({
      'x'         => 1,
      'y'         => 0,
      'height'    => 1,
      'width'     => 1,
      'absolutey' => 1,
    }) );
    return;
  }
  my $sample         = $Config->{'transcript'}->{'sample'};
  my $A = $self->my_config('type') eq 'bottom' ? 0 : 1;
 
  my %draw_coverage = (
    $coverage_levels[0] => [0, "grey70"],
    $coverage_levels[1] => [1, "grey40"],
  );


  # Drawing stuff
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'}; 
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);   
     


  foreach my $coverage ( sort { $a->[2]->level <=> $b->[2]->level } @$coverage_obj  ) {
    my $level  = $coverage->[2]->level;
    my $y =  $draw_coverage{$level}[0];
    my $z = 2+$y;# -19+$y;
       $y =  1 - $y if $A; 
       $y *= 2;
    my $h = 3 - $y;
       $y = 0;
    # Draw ------------------------------------------------
    my $S =  $coverage->[0];
    my $E =  $coverage->[1];
    my $width = $font_w_bp * length( $level );
    my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
    my $start = $coverage->[2]->start() + $offset;
    my $end   = $coverage->[2]->end() + $offset;
    my $pos   = "$start-$end";

    my $display_level = $level == $max_coverage ? ">".($level-1) : $level;
    my $bglyph = $self->Rect({
      'x'         => $S,
      'y'         => 8-$h,
      'height'    => $h,                            #$y,
      'width'     => $E-$S+1,
      'colour'    => $draw_coverage{$level}->[1],
      'absolutey' => 1,
      'href'      => $self->_url({'action' => 'ReadCoverage', 'pos' => $pos, 'sp' => $sample, 'disp_level' => $display_level}),
      'zmenu' => {
        'caption' => 'Resequencing read coverage: '.$display_level,
        "12:bp $pos" => '',
        "14:$sample" => '',
        "16:Source: Sanger",
      },
      'z'    => $z
    });
    #$self->join_tag( $bglyph, "$S:$E:$level", $A,$A, $draw_coverage{$level}->[1], 'fill',  $z );
    #$self->join_tag( $bglyph, "$S:$E:$level", 1-$A,$A, $draw_coverage{$level}->[1], 'fill',  $z );
    $self->push( $bglyph );
  }
}

sub error_track_name { return 'read coverage'; }

1;
