=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClassifyInterpro
#Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyInterpro

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: ckong $

=head VERSION

$Revision: 1.01 $

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClassifyInterpro;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyInterpro;

use strict;
use warnings;
use Data::Dumper;
use DBI;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'       => 1,
            'immediate_dataflow'  => 1,
            'member_type'         => 'protein',
            'input_id_prefix'     => 'protein',
           };
}

sub fetch_input {
    my ($self) = @_;

    my $release = $self->param('release');

return;
}

sub run {
    my ($self) = @_;
    $self->get_clusters;

return;
}

sub write_output {
    my ($self) = @_;
    
    $self->store_clusterset('default', $self->param('allclusters'));
return;
}

######################
# internal methods
######################
sub get_clusters {
    my ($self) = @_;

    my %allclusters 	 = ();
    $self->param('allclusters',\%allclusters);

    my $unknownByPanther      = 0;
    my $knownByPantherPTHR    = 0;
    my $knownByPantherSF      = 0;
    my $allMembers            = 0;

    my $platform         = "mysql";
    my $database         = "ckong_panther";
    my $host             = "mysql-eg-devel-2.ebi.ac.uk";
    my $port             = "4207";
    my $user             = "ensrw";
    my $pw               = "scr1b3d2";
    my $dsn              = "dbi:$platform:$database:$host:$port";
    my $pantherDB        = DBI->connect($dsn,$user,$pw);
    
    my $pantherSql       = "SELECT panther_family_id FROM panther_annot_8_1_EG20_EG_HUMAN_SF WHERE ensembl_id = ?";
    my $pantherSth       = $pantherDB->prepare($pantherSql);
    my $pantherSql2      = "SELECT panther_family_id FROM panther_annot_8_1_EG20_EG_HUMAN_PTHR WHERE ensembl_id = ?";
    my $pantherSth2      = $pantherDB->prepare($pantherSql2);

    my $mlss_id          = $self->param('mlss_id'); 
    my $SeqMemberAdaptor = $self->compara_dba->get_SeqMemberAdaptor;
    my $mlssAdaptor      = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss             = $mlssAdaptor->fetch_by_dbID($mlss_id);
    my $genomeDBs        = $mlss->species_set_obj->genome_dbs();

    my $genomeDB_id;my $genomeDB_name;   
    my $transcript_adaptor;my $translation_adaptor;
    my $job_count        = 0;

#    my $non_annot_members = "/nfs/nobackup2/ensemblgenomes/ckong/workspace/buildhmmprofiles/PLANTS_HMM2_non_annot_members_EG20_PANTHER_8_1_PTHR_SF.fa";
#    open my $data,">","$non_annot_members" or die $!;

    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host       => 'mysql-eg-mirror.ebi.ac.uk',
        -port       => 4205,
        -user       => 'ensrw',
        -pass       => 'writ3r',
        -db_version => '73', #$release,
    );

    for my $genomeDB (@$genomeDBs) {
        $genomeDB_id         = $genomeDB->dbID;
        $genomeDB_name       = $genomeDB->name;
 #       $translation_adaptor = Bio::EnsEMBL::Registry->get_adaptor($genomeDB_name,'core','Translation'); 
	my $members          = $SeqMemberAdaptor->fetch_all_canonical_by_source_genome_db_id('ENSEMBLPEP',$genomeDB_id);

        for my $mem (@$members) {
            my $member_id   = $mem->member_id;  
 	    my $member      = $SeqMemberAdaptor->fetch_by_dbID($member_id);
            my $stable_id   = $member->stable_id; 
#            my $translation = $translation_adaptor->fetch_by_stable_id($stable_id);
#            my $upi='NA';

 #           foreach my $dbEntry (@{$translation->get_all_DBLinks('UniParc') }){
# 	       next if (!$dbEntry || $dbEntry->dbname() ne "UniParc");
 #              $upi = $dbEntry->primary_id; 
# 	    }
#    	    print "$stable_id\t$upi\n";

            $pantherSth->execute($member->stable_id);
            $pantherSth2->execute($member->stable_id);
            my $res       = $pantherSth->fetchrow_arrayref;## SF
            my $res2      = $pantherSth2->fetchrow_arrayref;## PTHR
            $allMembers++;           	

	    if (defined $res->[0]) {
               my $fam = $res->[0];  
               $knownByPantherSF++;
	       push @{$allclusters{$fam}{members}}, $member->member_id;
               #$allclusters{$fam}{member}{$member->member_id} = 1; ## Avoid duplicates
	       #push @{$allclusters{$fam}{clusters}}, $member->member_id;
	    } 
#            elsif(defined $res2->[0]){
#               my $fam = $res2->[0];
#               $knownByPantherPTHR++;
#               push @{$allclusters{$fam}{members}}, $member->member_id;
#            }
            else {
               my $cluster_dir_count;
               $job_count++;

    	       if ($job_count < 1000){
       	         $cluster_dir_count = '/cluster_0';
    	       }
    	       else {
       	         my $remainder       = $job_count % 1000;
       	         my $quotient        = ($job_count - $remainder)/1000;
       	         $cluster_dir_count  = '/cluster_'.$quotient;
     	       }
               # Fan jobs for HMMer_classify using new created HMMer profiles for non-annotated Panther members 
               $self->dataflow_output_id( { 'non_annot_member' => $member_id,'genomeDB_id'=> $genomeDB_id,'cluster_dir_count'=>$cluster_dir_count }, 2);
               $unknownByPanther++;
#               my $seq = $member->sequence;
#      	       $seq    =~ s/(.{72})/$1\n/g;
#               chomp $seq;
#    	       print $data ">" . $member->member_id . "\n$seq\n";
           }
	}
   }
#   close($data);
   my $singleton_clusters=0;

   for my $model_name (keys %allclusters) {
      $allclusters{$model_name}{model_name} = $model_name;
      ## singleton clusters is filtered out in StoreClusters.pm
      if (scalar @{$allclusters{$model_name}{members}} == 1) {
      $singleton_clusters++;
   }
=pod
	 if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
         } else { 
 	   # If it is not a singleton, we add the name of the model to store in the db
 	   print STDERR Dumper $allclusters{$model_name};
	   my @members = keys %{$allclusters{$model_name}{members}};
	   delete $allclusters{$model_name}{members};
	   @{$allclusters{$model_name}{members}} = @members;
	   $allclusters{$model_name}{model_name} = $model_name
         }
=cut
   }

    print STDERR $self->param('allclusters')."\n" if ($self->debug());
    print STDERR "$allMembers members to be annotated\n" if ($self->debug());
    print STDERR "$knownByPantherSF members annotated in Panther SF\n" if ($self->debug());
    print STDERR "$knownByPantherPTHR members annotated in Panther PTHR\n" if ($self->debug());
    print STDERR "$unknownByPanther members missing in Panther\n" if ($self->debug());
    print STDERR "$singleton_clusters members in singleton cluster\n" if ($self->debug());
}


1;
