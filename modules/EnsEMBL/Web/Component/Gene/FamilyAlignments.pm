=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::FamilyAlignments;

### Displays embedded JalView link for a protein family

use strict;
use warnings;
no warnings "uninitialized";


use EnsEMBL::Web::Constants;
use EnsEMBL::Web::File::Dynamic;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $cdb     = shift || 'compara';
  my $object = $self->object;
  my $species = $object->species;
  my $html;

  my $fam_obj = $object->create_family($object->param('family'), $cdb);
  my $ensembl_members   = $fam_obj->get_Member_by_source('ENSEMBLPEP');
  my @all_pep_members;
  push @all_pep_members, @$ensembl_members;
  push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SPTREMBL')};
  push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SWISSPROT')};

  $html .= $self->_embed_jalview('Ensembl', $ensembl_members);
  $html .= $self->_embed_jalview('', \@all_pep_members);
  return $html;
}

sub _embed_jalview {
  my( $self, $type, $refs ) = @_;
  my $object   = $self->object;
  my $count    = @$refs;
  my $outcount = 0;
  return unless $count;
  
  my $file = EnsEMBL::Web::File::Dynamic->new(
                                              hub             => $self->hub,
                                              extension       => 'fa',
                                              input_drivers   => ['IO'],
                                              output_drivers  => ['IO'],
                                              );

  foreach my $member (@$refs) {
    my $align;
    eval { $align = $member->alignment_string; };
    unless ($@) {
      if($member->alignment_string) {
        $file->write_line([
                            $member->stable_id,
                            $member->alignment_string,
                          ]);
        $outcount++;
      }
    }
  }
  
  return unless $outcount;

  my $BASE = $object->species_defs->ENSEMBL_BASE_URL;
  my $URL  = $file->read_url;

  return qq(
  <p class="space-below">$count $type members of this family:
    <applet archive="$BASE/jalview/jalviewApplet.jar"
        code="jalview.bin.JalviewLite" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">

      <param name="file" value="$BASE$URL" />
      <param name="showFullId" value="false" />
      <param name="defaultColour" value="clustal" />
      <param name="showSequenceLogo" value="true" />
      <param name="showGroupConsensus" value="true" />
      <param name="nojmol" value="true" />
      <param name="application_url" value="http://www.jalview.org/services/launchApp" />

      <strong>Java must be enabled to view alignments</strong>
    </applet>
  </p>
);
}

        #code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
      #<param name="application_url" value="http://www.jalview.org/services/launchApp"> 

1;
