=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene;

use strict;

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::TmpFile::Image;

use base qw(EnsEMBL::Web::Component);

sub draw_structure {
  my ($self, $display_name, $is_thumbnail) = @_;
  my $html = '';

  my $r2r_path  = $self->hub->species_defs->ENSEMBL_TMP_DIR_IMG.'/r2r';
  my $filename  = $display_name.'-'.$self->hub->param('g');
  $filename    .= '-thumbnail' if $is_thumbnail;
  $filename    .= '.svg';
  my $svg_path  = $r2r_path.'/'.$filename;

  unless (-e $svg_path) { 
    $self->make_directory($r2r_path.'/');
    my $database = $self->hub->database('compara');
    if ($database) {
      my $gma = $database->get_GeneMemberAdaptor();
      my $sma = $database->get_SeqMemberAdaptor();
      my $gta = $database->get_GeneTreeAdaptor();

      my $member  = $gma->fetch_by_source_stable_id(undef, $self->object->stable_id);
      return unless $member;
      my $peptide = $sma->fetch_canonical_for_gene_member_id($member->member_id);

      my $gene_tree   = $gta->fetch_default_for_Member($member);
      return unless $gene_tree;
      my $model_name  = $gene_tree->get_tagvalue('model_name');
      my $ss_cons     = $gene_tree->get_tagvalue('ss_cons');
      return unless $ss_cons;
      my $input_aln   = $gene_tree->get_SimpleAlign( -id => 'MEMBER' );
      my $aln_file    = $self->_dump_multiple_alignment($input_aln, $model_name, $ss_cons);
      my ($thumbnail, $plot) = $self->_draw_structure($aln_file, $gene_tree, $peptide->stable_id,$filename);
      $filename = $is_thumbnail ? $thumbnail : $plot;
      $svg_path = $r2r_path.'/'.$filename;
    }
  }
  return $svg_path;
}

sub _dump_multiple_alignment {
    my ($self, $aln, $model_name, $ss_cons) = @_;
    if ($ss_cons =~ /^\.+$/) {
      warn "The tree has no structure\n";
      return undef;
    }

    my $aln_file  = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                    );

    my $content = "# STOCKHOLM 1.0\n";
    for my $aln_seq ($aln->each_seq) {
      $content .= sprintf ("%-20s %s\n", $aln_seq->display_id, $aln_seq->seq);
    }
    $content .= sprintf ("%-20s\n", "#=GF R2R keep allpairs");
    $content .= sprintf ("%-20s %s\n//\n", "#=GC SS_cons", $ss_cons);

    $aln_file->print($content);
    return $aln_file;
}

sub _get_aln_file {
  my ($self, $aln_file) = @_;

  my $input_path  = $aln_file->{'full_path'};
  my $output_path = $input_path . ".cons";
  ## For information about these options, check http://breaker.research.yale.edu/R2R/R2R-manual-1.0.3.pdf
  $self->_run_r2r_and_check("--GSC-weighted-consensus", $input_path, $output_path, "3 0.97 0.9 0.75 4 0.97 0.9 0.75 0.5 0.1");

  return $output_path;
}

sub _draw_structure {
    my ($self, $aln_file, $tree, $peptide_id, $svg_path) = @_;

    my $output_path = $self->_get_aln_file($aln_file);
    my $r2r_path    = $self->hub->species_defs->ENSEMBL_TMP_DIR_IMG.'/r2r/';

    my $th_meta = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                        extension => ".meta",
                    );
    my $th_content = "$output_path\tskeleton-with-pairbonds\n";
    $th_meta->print($th_content);
    my $thumbnail = $svg_path;
    $self->_run_r2r_and_check("", $th_meta->{'full_path'}, $r2r_path.$thumbnail, "");

    my $meta_file  = EnsEMBL::Web::TmpFile::Text->new(
                        prefix   => 'r2r/'.$self->hub->species,
                        extension => ".meta",
                    );
    my $content = "$output_path\n";
    $content .= $aln_file->{'full_path'}."\toneseq\t$peptide_id\n";
    $meta_file->print($content);

    $self->_run_r2r_and_check("", $meta_file->{'full_path'}, $r2r_path.$svg_path, "");

    return ($thumbnail, $svg_path);
}

sub _run_r2r_and_check {
    my ($self, $opts, $infile, $outfile, $extra_params) = @_;
    my $r2r_exe = $self->hub->species_defs->R2R_BIN;
    warn "$r2r_exe doesn't exist" unless ($r2r_exe);

    my $cmd = "$r2r_exe $opts $infile $outfile $extra_params";
    system($cmd);
    if (! -e $outfile) {
       warn "Problem running r2r: $outfile doesn't exist\nThis is the command I tried to run:\n$cmd\n";
    }
    return;
}


1;

