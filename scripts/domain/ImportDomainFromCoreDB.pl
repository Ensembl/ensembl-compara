#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Domain;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;

$| = 1;

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  (-host => "ecs2e",
   -user => "ensadmin",
   -pass => "ensembl",
   -dbname => "abel_new_compara_test",
   -conf_file => "/nfs/acari/abel/src/ensembl_main/compara-family-merge/modules/Bio/EnsEMBL/Compara/Compara.conf");


my $gdb = $compara_db->get_GenomeDBAdaptor;
my $TaxonAdaptor = $compara_db->get_TaxonAdaptor;
my $DomainAdaptor = $compara_db->get_DomainAdaptor;

foreach my $genomedb (@{$gdb->fetch_all}) {
  my $index = 1;
  my %cached_members;
  print STDERR "species_assembly: ",$genomedb->name," ",$genomedb->assembly," ",time,"\n";

  my %domain;
  my %member_added_to_domain_ip;
  my $taxon = $TaxonAdaptor->fetch_by_dbID($genomedb->taxon_id);
  
  my $dba = $compara_db->get_db_adaptor($genomedb->name,$genomedb->assembly);
  my $tla = $dba->get_TranslationAdaptor;
  my $tca = $dba->get_TranscriptAdaptor;
  my $pfa = $dba->get_ProteinFeatureAdaptor;
  my $ga = $dba->get_GeneAdaptor;
  foreach my $transcript_id (@{$tca->list_dbIDs}) {
    my $transcript = $tca->fetch_by_dbID($transcript_id);
    my $translation = $transcript->translation;

    # take care of pseudogenes
    next unless (defined $translation);

    print STDERR "translation_stable_id: ",$translation->stable_id,"\n";
    my $pfs = $pfa->fetch_by_translation_id($translation->dbID);
    print STDERR "has ",scalar @{$pfs}," protein features\n";

    foreach my $pf (@{$pfs}) {
      my $domain;
      my $domain_ip;

      # creating/retrieving from cache a domain object (not INTERPRO)
      unless (defined $domain{$pf->analysis->logic_name . $pf->hseqname}) {
        my $logic_name;
        my $hseqname;
        unless (defined $pf->idesc) {
          my $idesc;
          if ($pf->analysis->logic_name =~ /ncoils/i) {
            $idesc = "NCOILS";
            $logic_name = "NCOILS";
            $hseqname = "NCOILS";
          } elsif ($pf->analysis->logic_name =~ /tmhmm/i) {
            $idesc = "TRANSMEMBRANE";
            $logic_name = "TMHMM";
            $hseqname = "TMHMM";
          } elsif ($pf->analysis->logic_name =~ /seg/i) {
            $idesc = "LOW_COMPLEXITY";
            $logic_name = "SEG";
            $hseqname = "SEG";
          } elsif ($pf->analysis->logic_name =~ /signalp/i) {
            $idesc = "SIGNAL_PEPTIDE";
            $logic_name = "SIGNALP";
            $hseqname = "SIGNALP";
          }
          $pf->idesc($idesc);
        }
        unless (defined $logic_name) {
          if ($pf->analysis->logic_name =~ /pfam/i) {
            $logic_name = "PFAM";
          } elsif ($pf->analysis->logic_name =~ /prints/i) {
            $logic_name = "PRINTS";
          } elsif ($pf->analysis->logic_name =~ /prosite/i) {
            $logic_name = "PROSITE";
          } elsif ($pf->analysis->logic_name eq "pfscan" ||
                   $pf->analysis->logic_name eq "PROFILE") {
            $logic_name = "PROFILE";
          }
        }
        unless (defined $logic_name) {
          print STDERR "logic_name not defined\n";
          print STDERR "protein feature logic name is: ",$pf->analysis->logic_name,"\n";
          die;
        }
        unless (defined $hseqname) {
          $hseqname = $pf->hseqname;
        }
        $domain = Bio::EnsEMBL::Compara::Domain->new_fast
          ({
            '_stable_id' => $hseqname,
            '_source_name' => $logic_name,
            '_description' => $pf->idesc,
           });
        $domain{$pf->analysis->logic_name . $pf->hseqname} = $domain;
      } else {
        $domain = $domain{$pf->analysis->logic_name . $pf->hseqname};
      }

      # creating/retrieving from cache a INTERPRO domain object 
      if (defined $pf->interpro_ac) {
        unless (defined $domain{"INTERPRO" . $pf->interpro_ac}) {
          $domain_ip = Bio::EnsEMBL::Compara::Domain->new_fast
            ({
              '_stable_id' => $pf->interpro_ac,
              '_source_name' => "INTERPRO",
              '_description' => $pf->idesc,
             });
          $domain{"INTERPRO" . $pf->interpro_ac} = $domain_ip;
        } else {
          $domain_ip = $domain{"INTERPRO" . $pf->interpro_ac};
        }
      }

      # creating Member if not already cached, dramatic speed gain
      unless (defined $cached_members{$translation->stable_id}) {
        my $empty_slice = new Bio::EnsEMBL::Slice(-empty => 1,
                                                  -adaptor => $dba->get_SliceAdaptor());

        my %ex_hash;
        foreach my $exon (@{$transcript->get_all_Exons}) {
          $ex_hash{$exon} = $exon->transform($empty_slice);
        }
        $transcript->transform(\%ex_hash);

        my $member = Bio::EnsEMBL::Compara::Member->new_fast
          ({
            '_stable_id' => $translation->stable_id,
            '_taxon_id' => $genomedb->taxon_id,
            '_taxon' => $taxon,
            '_description' => "NULL",
            '_genome_db_id' => $genomedb->dbID,
            '_chr_name' => $transcript->get_all_Exons->[0]->contig->chr_name,
            '_chr_start' => $transcript->coding_region_start,
            '_chr_end' => $transcript->coding_region_end,
            '_source_name' => "ENSEMBLPEP",
            '_sequence' => $transcript->translate->seq,
           });
        $cached_members{$translation->stable_id} = $member;
      }

      my $member = $cached_members{$translation->stable_id};

      my $attribute = Bio::EnsEMBL::Compara::Attribute->new_fast
        ({
          'member_start' => $pf->start,
          'member_end' => $pf->end
         });

      $domain->add_Member_Attribute( [ $member, $attribute ] );

      if (defined $domain_ip) {
        unless (defined $member_added_to_domain_ip{$domain_ip->stable_id . $member->stable_id}) {
          my $attribute_ip = Bio::EnsEMBL::Compara::Attribute->new_fast
            ({
              'member_start' => "NULL",
              'member_end' => "NULL"
             });
          $domain_ip->add_Member_Attribute( [ $member, $attribute_ip ] );
          $member_added_to_domain_ip{$domain_ip->stable_id . $member->stable_id} = 1;
        }
      }
#      print STDERR $pf->analysis->logic_name," ";
#      print STDERR $pf->hseqname," ",$pf->start," ",$pf->end," ";
#      print STDERR $pf->interpro_ac," " if (defined $pf->interpro_ac);
#      print STDERR $pf->idesc," " if (defined $pf->idesc);
#      print STDERR $member->sequence," ";
#      print STDERR "\n";
    }
#    print STDERR "------\n";
#    $index++;
#    last if ($index > 3);
  }
  print STDERR "end time1: ",time,"\n";
#  exit;
  foreach my $domain (values %domain) {
    $DomainAdaptor->store($domain);
  }
  print STDERR "end time2: ",time,"\n";
}
