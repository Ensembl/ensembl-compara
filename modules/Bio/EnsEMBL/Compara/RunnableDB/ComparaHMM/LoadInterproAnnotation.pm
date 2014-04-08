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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadInterproAnnotation

=head1 DESCRIPTION

=head1 AUTHOR

ChuangKee Ong

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadInterproAnnotation;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my ($self) = @_;

    $self->store_annotation($self->param('panther_annot_PTHR')) if $self->param('panther_annot_PTHR');
    $self->store_annotation($self->param('panther_annot_SF')) if $self->param('panther_annot_SF');
}


######################
# internal methods
######################
sub store_annotation {
    my ($self, $file) = @_;
   
    my $sql;

    if($file=~/SF/){

       $sql = "LOAD DATA LOCAL INFILE ? 
                INTO TABLE panther_annot_SF
                FIELDS TERMINATED BY '\\t'
                LINES TERMINATED BY '\\n'
                (upi, ensembl_id, ensembl_div, panther_family_id, start, end, score, evalue)";
    }
    else {

       $sql = "LOAD DATA LOCAL INFILE ? 
                INTO TABLE panther_annot_PTHR
                FIELDS TERMINATED BY '\\t'
                LINES TERMINATED BY '\\n'
                (upi, ensembl_id, ensembl_div, panther_family_id, start, end, score, evalue)";
    }

   my $sth    = $self->compara_dba->dbc->prepare($sql);
   $sth->execute($file);
   $sth->finish();
}


1;
