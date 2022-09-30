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

package EnsEMBL::Web::Document::Image::R2R;

use strict;

use EnsEMBL::Web::File::Dynamic;

use base qw(EnsEMBL::Web::Document::Image);

sub render {
  my ($self, $display_name, $is_thumbnail) = @_;

  my $database = $self->hub->database('compara');

  my ($found_compara, $found_core, $aln_array, $transcript_stable_id, $model_name, $ss_cons);

  ## Let's try to get the secondary structure from the Compara database
  ($found_compara, $aln_array, $transcript_stable_id, $model_name, $ss_cons) = $self->find_ss_in_compara($database) if $database;

  ## Or from Core
  ($found_core, $aln_array, $transcript_stable_id, $model_name, $ss_cons) = $self->find_ss_in_core() unless $found_compara;
  return unless ($found_compara or $found_core);

  ## Here, we can do the drawing
  my $name      = $display_name.'-'.$self->hub->param('g');
  my $filename  = $name.($is_thumbnail ? '_thumbnail' : '').'.svg';

  my $aln_file  = $self->_dump_multiple_alignment($aln_array, $model_name, $ss_cons);
  my ($thumbnail_path, $plot_path) = $self->_create_svg($aln_file, $transcript_stable_id, $model_name, $found_compara ? 1 : 0);
  return $is_thumbnail ? $thumbnail_path : $plot_path;
}

sub find_ss_in_compara {
    my ($self, $database) = @_;

    my $gma = $database->get_GeneMemberAdaptor();
    my $gta = $database->get_GeneTreeAdaptor();

    my $member = $gma->fetch_all_by_stable_id_GenomeDB($self->component->object->stable_id);
    if ($member and $member->has_GeneTree) {
      my $transcript = $member->get_canonical_SeqMember();
      my $gene_tree  = $gta->fetch_default_for_Member($member);
      if ($gene_tree) {
        my $model_name = $gene_tree->get_tagvalue('model_name');
        my $ss_cons    = $gene_tree->get_tagvalue('ss_cons');
        if ($ss_cons) {
          my $input_aln = $gene_tree->get_SimpleAlign();
          my @aln_array = map {[$_->display_id, $_->seq]} $input_aln->each_seq;
          return (1, \@aln_array, $transcript->stable_id, $model_name, $ss_cons);
        }
      }
    }
    return (0);
}

sub find_ss_in_core {
    my ($self) = @_;
    my $gene        = $self->hub->core_object('gene')->Obj;
    my $transcript  = $gene->canonical_transcript;
    if ($transcript) {
      my $model_name  = $gene->display_xref && $gene->display_xref->display_id || $gene->stable_id;
      my $ss_attr     = $transcript->get_all_Attributes('ncRNA');
      if ($ss_attr and scalar(@$ss_attr)) {
        my $ss_cons = $ss_attr->[0]->value;
           $ss_cons =~ s/^.*\t//;
           $ss_cons =~ s/([().])(\d+)/$1 x $2/ge; #Expand
        my $seq     = $transcript->spliced_seq;
        if (length($seq) == length($ss_cons)) {
          my @aln_array = ([$transcript->stable_id, $seq]);
          return (1, [[$transcript->stable_id, $seq]], $transcript->stable_id, $model_name, $ss_cons);
        }
      }
    }
    return (0);
}

sub _dump_multiple_alignment {
    my ($self, $aln_array, $model_name, $ss_cons) = @_;
    if ($ss_cons =~ /^\.+$/) {
      warn "The tree has no structure\n";
      return undef;
    }

    ## Note - r2r needs a file on disk, so we explicitly set the driver to IO
    my $aln_file  = EnsEMBL::Web::File::Dynamic->new(
                                                      hub             => $self->hub,
                                                      sub_dir         => 'r2r_'.$self->hub->species,
                                                      name            => $model_name.'.aln',
                                                      input_drivers   => ['IO'],
                                                      output_drivers  => ['IO'],
                                                      );

    unless ($aln_file->exists) {
      my $content = "# STOCKHOLM 1.0\n";
      for my $aln_seq (@$aln_array) {
        $content .= sprintf ("%-20s %s\n", @$aln_seq);
      }
      $content .= sprintf ("%-20s\n", "#=GF R2R keep allpairs");
      $content .= sprintf ("%-20s %s\n//\n", "#=GC SS_cons", $ss_cons);

      $aln_file->write($content);
    }
    return $aln_file;
}



sub _create_svg {
    my ($self, $aln_file, $peptide_id, $model_name, $with_consensus_structure) = @_;

    ## Path to the files we dumped earlier
    my $sub_dir = 'r2r_'.$self->hub->species;
    my $path    = $aln_file->base_read_path.'/'.$sub_dir;

    my $cons_filename  = $model_name.'.cons';
    ## For information about these options, check http://breaker.research.yale.edu/R2R/R2R-manual-1.0.3.pdf
    $self->_run_r2r_and_check("--GSC-weighted-consensus", $aln_file->absolute_read_path, $path, $cons_filename, "3 0.97 0.9 0.75 4 0.97 0.9 0.75 0.5 0.1");

    my $thumbnail = $model_name.'_thumbnail.svg';

    ## Note - r2r needs a file on disk, so we explicitly set the driver to IO
    my $th_file = EnsEMBL::Web::File::Dynamic->new(
                                                  hub             => $self->hub,
                                                  sub_dir         => $sub_dir,
                                                  name            => $thumbnail,
                                                  input_drivers   => ['IO'],
                                                  output_drivers  => ['IO'],
                                                  );

    unless ($th_file->exists) {

      my $th_meta = EnsEMBL::Web::File::Dynamic->new(
                                                  hub             => $self->hub,
                                                  sub_dir         => $sub_dir,
                                                  name            => $model_name.'_thumbnail.meta',
                                                  input_drivers   => ['IO'],
                                                  output_drivers  => ['IO'],
                                                  );
      unless ($th_meta->exists) {
        my $th_content = "$path/$cons_filename\tskeleton-with-pairbonds\n";
        $th_meta->write($th_content);
      }
      $self->_run_r2r_and_check("--disable-usage-warning", $th_meta->absolute_read_path, $path, $thumbnail, "");
    }

    my $plot = $model_name.'.svg';

    ## Note - r2r needs a file on disk, so we explicitly set the driver to IO
    my $plot_file = EnsEMBL::Web::File::Dynamic->new(
                                                  hub             => $self->hub,
                                                  sub_dir         => $sub_dir,
                                                  name            => $plot,
                                                  input_drivers   => ['IO'],
                                                  output_drivers  => ['IO'],
                                                  );

    unless ($plot_file->exists) {

      my $plot_meta  = EnsEMBL::Web::File::Dynamic->new(
                                                      hub             => $self->hub,
                                                      sub_dir         => $sub_dir,
                                                      name            => $model_name.'.meta',
                                                      input_drivers   => ['IO'],
                                                      output_drivers  => ['IO'],
                                                      );


      unless ($plot_meta->exists) {
        my $content = $with_consensus_structure ? "$path/$cons_filename\n" : '';
        $content .= $aln_file->absolute_read_path."\toneseq\t$peptide_id\n";
        $plot_meta->write($content);
      }

      $self->_run_r2r_and_check("--disable-usage-warning", $plot_meta->absolute_read_path, $path, $plot, "");
    }

    return ($th_file->read_url, $plot_file->read_url);
}

sub _run_r2r_and_check {
    my ($self, $opts, $inpath, $outpath, $outfile, $extra_params) = @_;
    my $r2r_exe = $self->hub->species_defs->R2R_BIN;
    warn "$r2r_exe doesn't exist" unless ($r2r_exe);

    ## Make temporary directory
    mkdir($outpath) unless -e $outpath;
    $outpath .= '/'.$outfile;

    my $cmd = "$r2r_exe $opts $inpath $outpath $extra_params";
    system($cmd);
    if (! -e $outpath) {
       warn "Problem running r2r: $outpath doesn't exist\nThis is the command I tried to run:\n$cmd\n";
    }
    return;
}


1;

