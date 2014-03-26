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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PantherLoadModels


=head1 SYNOPSIS



=head1 DESCRIPTION

This Analysis/RunnableDB is designed to fetch the HMM models from
the Panther ftp site and load them into the database to be used in the
alignment process.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherLoadModels;

use strict;
use IO::File; # ??
use File::Basename;
use Data::Dumper;
use vars qw/@INC/;
use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels');

sub param_defaults {

    return {
            'type' => 'panther9.0_treefam',
            'url'  => 'ftp://ftp.pantherdb.org/panther_library/current_release',
            'remote_file' => 'PANTHER9.0_ascii.tgz',
            'expanded_basename' => 'PANTHER9.0',
            'expander' => 'tar -xzf ',
           }
}
my $type;

sub fetch_input {
    my ($self) = @_;

    my $pantherScore_path = $self->param('pantherScore_path');
    $self->throw('pantherScore_path is an obligatory parameter') unless (defined $self->param('pantherScore_path'));
    my $type              = $self->param('type');
    $self->throw('type is an obligatory parameter') unless (defined $self->param('type'));

    push @INC, "$pantherScore_path/lib";
    require FastaFile;
    import FastaFile;

}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Downloads and processes
    Returns :   none
    Args    :   none

=cut
sub run {
    my $self = shift @_;

    ### If you don't want to download the models, define the parameter cm_file_or_directory to point to the panther path
    if ($self->param('cm_file_or_directory')) {
        $self->param('profiles_already_there', 1);
        return;
    }

    $self->download_models;
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores the HMM models
    Returns :   none
    Args    :   none

=cut
sub write_output {
    my $self = shift @_;

    #return if $self->param('profiles_already_there');
    if($type!~/^new/){
      $self->get_profiles();
    }
    else
    {
      $self->get_profiles_2();
    }
    #$self->clean_directory();
}

######################
# internal methods
#####################
sub get_profiles {
    my ($self) = @_;

    my $cm_directory = $self->param('cm_file_or_directory');
    $self->throw('cm_file_or_directory is an obligatory parameter') unless (defined $self->param('cm_file_or_directory'));
    print STDERR "CM_DIRECTORY = " . $cm_directory . "\n";
    
    my $consensus_fasta = $cm_directory . "/globals/con.Fasta";
    open my $consensus_fh, "<", $consensus_fasta or die "$!: $consensus_fasta";
    my $index           = FastaFile::indexFasta($consensus_fh);
    
    $cm_directory .= "/books";
    
    while (my $famPath = <$cm_directory/*>) {
        my $fam        = basename($famPath);
        my $cons_seq   = FastaFile::getSeq($consensus_fh, $index, $fam);
        if (! defined $cons_seq) {
            print STDERR "No consensus sequence found for fam $fam" unless(defined $cons_seq);
            next; ## If we don't have consensus seq we don't store the hmm_profile
        }
        my (undef, $seq) = split /\n/, $cons_seq, 2;
        print STDERR "Storing family $famPath($fam) => $famPath/hmmer.hmm\n" if ($self->debug());
        $self->store_hmmprofile("$famPath/hmmer.hmm", $fam, $seq,$type);

	## For subfamilies
        while (my $subfamPath  = <$famPath/*>) {
            my $subfamBasename = basename($subfamPath);
            next if ($subfamBasename eq 'hmmer.hmm' || $subfamBasename eq 'tree.tree' || $subfamBasename eq 'cluster.pir');
            my $subfam = $subfamBasename =~ /hmmer\.hmm/ ? $fam : "$fam." . $subfamBasename;
            print STDERR "Storing $subfam HMM\n";
            $self->store_hmmprofile("$subfamPath/hmmer.hmm", $subfam,$type);
        }
    }
}

sub get_profiles_2 {
    my ($self) = @_;

    my $cm_directory = $self->param('cm_file_or_directory');
    $self->throw('cm_file_or_directory is an obligatory parameter') unless (defined $self->param('cm_file_or_directory'));
 
    print STDERR "CM_DIRECTORY = " . $cm_directory . "\n";

    while (my $famPath = <$cm_directory/*>) {
        my $fam       = basename($famPath);
        print STDERR "Storing family $famPath($fam) => $famPath/hmmer.hmm\n" if ($self->debug());

        my $hmmfile   = "$famPath/hmmer.hmm"; 
        $self->param('hmmfile',$hmmfile);
        next unless (-e $hmmfile);

        my $consensus = $self->get_consensus_from_HMMs();
        my $name;

        open my $fh, "<", $hmmfile or die $!;
          while (<$fh>) {
            if (/^NAME/) {
              $name   = (split /\s+/, $_)[1];
            }
          }
        close($fh);

        $self->store_hmmprofile("$famPath/hmmer.hmm", $fam, $consensus->{$name},$type);
   }
}

sub get_consensus_from_HMMs {
    my ($self) = @_;

    my $hmmemit_exe = $self->param('hmmemit_exe');
    $self->throw('hmmemit_exe is an obligatory parameter') unless (defined $self->param('hmmemit_exe'));

    my $hmmfile      = $self->param('hmmfile');

    open my $pipe, "-|", "$hmmemit_exe -c $hmmfile" or die $!;

    my %consensus;
    my $header;
    my $count = 0;
    my $seq;

    while (<$pipe>) {
        chomp;
        if (/^>/) {
            $consensus{$header} = $seq if (defined $header);
            ($header)           = $_ =~ /^>(.+?)\s/;
            $count++;
            $seq = "";
            next;
        }
        $seq .= $_ if (defined $header);
    }

    $consensus{$header} = $seq;
    close($pipe);

return \%consensus;
}


1;
