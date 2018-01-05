=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HighConfidenceOrthologs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HighConfidenceOrthologs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'perc_id_thresh'    => 30,
        'perc_cov_thresh'   => 60,
        'mlss_id'           => '51265',
        'condition'         => '($goc && $wga) || $is_tree_compliant',
 
    };
}

# fetch_input is expected to populate an array in $self->param('query_members')

sub fetch_input {
    my $self = shift @_;
    print "\n fetch input sub  ..........      :     \n\n" if $self->debug();
    $self->param('mlss_adap', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor);
    my $mlss_id = $self->param_required('mlss_id');
    my $mlss_obj = $self->param('mlss_adap')->fetch_by_dbID($self->param_required('mlss_id'));
    $self->param( 'mlss_obj', $mlss_obj ); 

    $self->param('goc_thresh' , $self->param('mlss_obj')->get_tagvalue('goc_quality_threshold') );
    $self->param('wga_thresh' , 50 );

    my $query = "SELECT homology_id from homology where method_link_species_set_id = $mlss_id";
    my $homologs =  $self->compara_dba->dbc->db_handle->selectcol_arrayref($query);
    print scalar @{$homologs} if $self->debug() >1;
    $self->param( 'orthologs', $homologs );
}

sub run {
    my $self = shift @_;
    print "\n run sub  ..........      :     \n\n" if $self->debug();

    $self->_ortholog_stats();
    
    my @orthologs = @{$self->param('orthologs')};
    my $count = 0;
    print "  1 to 1 orthologs    :     \n\n\n";
    my $ortholog_stats_1to1 = $self->param('HighConfidence1to1');
    $self->_eval_condition($ortholog_stats_1to1);
    print "  1 to Many orthologs    :     \n\n\n";
    my $ortholog_stats_1toMany = $self->param('HighConfidence1toMany');
    $self->_eval_condition($ortholog_stats_1toMany);
    print "  Many to Many orthologs    :     \n\n\n";
    my $ortholog_stats_ManytoMany = $self->param('HighConfidenceManytoMany');
    $self->_eval_condition($ortholog_stats_ManytoMany);

}

sub _eval_condition {
    my $self = shift @_;
    my $result_href = shift @_;
    print Dumper($result_href) if ($self->debug() >1);
    my @orthologs = @{$self->param('orthologs')};
    my $count = 0;
    foreach my $ortholog_id (@orthologs) {
        my $wga = $result_href->{$ortholog_id}->{'wga'};
        my $goc = $result_href->{$ortholog_id}->{'goc'};
        my $identity = $result_href->{$ortholog_id}->{'identity'};
        my $coverage = $result_href->{$ortholog_id}->{'coverage'};
        my $is_tree_compliant = $result_href->{$ortholog_id}->{'is_tree_compliant'};

        if (eval $self->param('condition') ) {
            print "it passed   :    $ortholog_id \n";
        }
        else{
            print "it failed   :    $ortholog_id \n";
        }
        $count++;
#        if ($count ==100) {
#            last;
#        }
    }
}

sub _ortholog_stats {
    my $self = shift @_;
    print "\n _single sub  ..........      :     \n\n" if $self->debug();
    my $mlss_id = $self->param_required('mlss_id');
    my $result;

    my $result_treeC = $self->_tree_compliant($self->param_required('mlss_id') );
    my $result_goc = $self->_goc($self->param_required('mlss_id'),$self->param('goc_thresh'));
    my $result_wga = $self->_wga($self->param_required('mlss_id'), $self->param('wga_thresh'));  
    my $result_id = $self->_identity($self->param_required('mlss_id'), $self->param_required('perc_id_thresh'));  
    my $result_cov = $self->_coverage($self->param_required('mlss_id'), $self->param('perc_cov_thresh') );
    
    my $tmp_result= $self->_deep_hash_merge($result_treeC->[0]->[0],$result_goc->[0]->[0]);
    my $tmp_result1= $self->_deep_hash_merge($tmp_result,$result_wga->[0]->[0]);
    my $tmp_result2= $self->_deep_hash_merge($tmp_result1,$result_id->[0]->[0]);
    my $tmp_result3= $self->_deep_hash_merge($tmp_result2,$result_cov->[0]->[0]);

    $self->param('HighConfidence1to1', $tmp_result3);

    $tmp_result= $self->_deep_hash_merge($result_treeC->[0]->[1],$result_goc->[0]->[1]);
    $tmp_result1= $self->_deep_hash_merge($tmp_result,$result_wga->[0]->[1]);
    $tmp_result2= $self->_deep_hash_merge($tmp_result1,$result_id->[0]->[1]);
    $tmp_result3= $self->_deep_hash_merge($tmp_result2,$result_cov->[0]->[1]);

    $self->param('HighConfidence1toMany', $tmp_result3);

    $tmp_result= $self->_deep_hash_merge($result_treeC->[0]->[2],$result_goc->[0]->[2]);
    $tmp_result1= $self->_deep_hash_merge($tmp_result,$result_wga->[0]->[2]);
    $tmp_result2= $self->_deep_hash_merge($tmp_result1,$result_id->[0]->[2]);
    $tmp_result3= $self->_deep_hash_merge($tmp_result2,$result_cov->[0]->[2]);

    $self->param('HighConfidenceManytoMany', $tmp_result3);
    
}

sub _goc { 
    my $self = shift @_;
    print "\n _goc sub  ..........      :     \n\n" if $self->debug();
    my $result_href = {'1to1' => 0, '1tomany' => 0, 'manytomany' => 0};
    my @HCO ;
    my ($mlss_id, $goc_thresh) = @_;
    my $query = "SELECT homology_id, CASE WHEN goc_score is NULL THEN NULL WHEN goc_score >= $goc_thresh THEN  1 ELSE  0 END AS goc FROM homology WHERE method_link_species_set_id = $mlss_id  AND description = 'ortholog_one2one' "; 
    my $high_orth = $self->compara_dba->dbc->db_handle->selectall_hashref($query,'homology_id'); 
    my $query2 = "SELECT homology_id, CASE WHEN goc_score is NULL THEN NULL WHEN goc_score >= $goc_thresh THEN  1 ELSE  0 END AS goc FROM homology WHERE method_link_species_set_id = $mlss_id  AND description = 'ortholog_one2many' ";
    my $high_orth2 = $self->compara_dba->dbc->db_handle->selectall_hashref($query2,'homology_id');
    my $query3 = "SELECT homology_id, CASE WHEN goc_score is NULL THEN NULL  WHEN goc_score >= $goc_thresh THEN  1 ELSE  0 END AS goc FROM homology WHERE method_link_species_set_id = $mlss_id  AND description = 'ortholog_many2many'  ";
    my $high_orth3 = $self->compara_dba->dbc->db_handle->selectall_hashref($query3,'homology_id');

    $result_href->{'1to1'} = scalar keys %{$high_orth};
    $result_href->{'1tomany'} = scalar keys %{$high_orth2};
    $result_href->{'manytomany'} = scalar keys %{$high_orth3};
    
    @HCO =($high_orth, $high_orth2, $high_orth3 );

    my @temp_result = (\@HCO, $result_href);
    print Dumper($result_href) if ($self->debug() >1);
    $self->param('goc_result', \@temp_result);
    
}

sub _wga { 
    my $self = shift @_;
    print "\n _wga sub  ..........      :     \n" if $self->debug();
    my ($mlss_id, $wga_thresh) = @_; 
    my $result_href = {'1to1' => 0, '1tomany' => 0, 'manytomany' => 0};
    my @HCO ;
    my $query = "SELECT homology_id, CASE WHEN wga_coverage is NULL then NULL WHEN wga_coverage >= $wga_thresh THEN  1 ELSE  0 END AS wga FROM homology where method_link_species_set_id = $mlss_id and description = 'ortholog_one2one' ";
    my $high_orth = $self->compara_dba->dbc->db_handle->selectall_hashref($query, 'homology_id');
    my $query2 = "SELECT homology_id, CASE WHEN wga_coverage is NULL then NULL WHEN wga_coverage >= $wga_thresh THEN  1 ELSE  0 END AS wga FROM homology where method_link_species_set_id = $mlss_id and description = 'ortholog_one2many' ";
    my $high_orth2 = $self->compara_dba->dbc->db_handle->selectall_hashref($query2, 'homology_id');
    my $query3 = "SELECT homology_id, CASE WHEN wga_coverage is NULL then NULL WHEN wga_coverage >= $wga_thresh THEN  1 ELSE  0 END AS wga FROM homology where method_link_species_set_id = $mlss_id and description = 'ortholog_many2many' ";
    my $high_orth3 = $self->compara_dba->dbc->db_handle->selectall_hashref($query3, 'homology_id');

    $result_href->{'1to1'} = scalar keys %{$high_orth};
    $result_href->{'1tomany'} = scalar keys %{$high_orth2};
    $result_href->{'manytomany'} = scalar keys %{$high_orth3};
    
    @HCO =($high_orth, $high_orth2, $high_orth3 );

    my @temp_result = (\@HCO, $result_href);
    print Dumper($result_href) if ($self->debug() >1);
    $self->param('wga_result', \@temp_result);
}

sub _tree_compliant { 
    my $self = shift @_;
    print "\n _tree_compliant ..........      :     \n" if $self->debug();
    my $mlss_id = shift @_;
    my $result_href = {'1to1' => 0, '1tomany' => 0, 'manytomany' => 0};
    my @HCO ;
    my $query = "SELECT homology_id, is_tree_compliant from homology where method_link_species_set_id = $mlss_id and description = 'ortholog_one2one' ";
    my $high_orth = $self->compara_dba->dbc->db_handle->selectall_hashref($query, 'homology_id');
    my $query2 = "SELECT homology_id, is_tree_compliant from homology where method_link_species_set_id = $mlss_id and description = 'ortholog_one2many'  ";
    my $high_orth2 = $self->compara_dba->dbc->db_handle->selectall_hashref($query2, 'homology_id');
    my $query3 = "SELECT homology_id, is_tree_compliant from homology where method_link_species_set_id = $mlss_id and description = 'ortholog_many2many' ";
    my $high_orth3 = $self->compara_dba->dbc->db_handle->selectall_hashref($query3, 'homology_id');

    $result_href->{'1to1'} = scalar keys %{$high_orth};
    $result_href->{'1tomany'} = scalar keys %{$high_orth2};
    $result_href->{'manytomany'} = scalar keys %{$high_orth3};
    
    @HCO =($high_orth, $high_orth2, $high_orth3 );

    my @temp_result = (\@HCO, $result_href);
    print Dumper($result_href) if ($self->debug() >1);
    $self->param('tc_result', \@temp_result);

}
    
sub _identity { 
    my $self = shift @_;
    print "\n percentage identity :     \n" if $self->debug();
    my ($mlss_id, $perc_id_thresh) = @_;
    my $result_href = {'1to1' => 0, '1tomany' => 0, 'manytomany' => 0};
    my @HCO ;
    my $query = "SELECT homology_id, CASE WHEN min(perc_id) >= $perc_id_thresh THEN  1 ELSE  0 END AS identity from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_one2one' GROUP BY homology_id ";
    my $high_orth = $self->compara_dba->dbc->db_handle->selectall_hashref($query, 'homology_id');
    my $query2 = "SELECT homology_id, CASE WHEN min(perc_id) >= $perc_id_thresh THEN  1 ELSE  0 END AS identity from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_one2many' GROUP BY homology_id ";
    my $high_orth2 = $self->compara_dba->dbc->db_handle->selectall_hashref($query2, 'homology_id');
    my $query3 = "SELECT homology_id, CASE WHEN min(perc_id) >= $perc_id_thresh THEN  1 ELSE  0 END AS identity from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_many2many' GROUP BY homology_id ";
    my $high_orth3 = $self->compara_dba->dbc->db_handle->selectall_hashref($query3, 'homology_id');

    $result_href->{'1to1'} = scalar keys %{$high_orth};
    $result_href->{'1tomany'} = scalar keys %{$high_orth2};
    $result_href->{'manytomany'} = scalar keys %{$high_orth3};
    
    @HCO =($high_orth, $high_orth2, $high_orth3 );

    my @temp_result = (\@HCO, $result_href);
    print Dumper($result_href) if ($self->debug() >1);
    $self->param('identity_result',\@temp_result);
}

sub _coverage { 
    my $self = shift @_;
    print "\n percentage coverage :     \n" if $self->debug();
    my ($mlss_id, $perc_cov_thresh) = @_;
    my $result_href = {'1to1' => 0, '1tomany' => 0, 'manytomany' => 0};
    my @HCO ;
    my $query = "SELECT homology_id, CASE WHEN min(perc_cov) >= $perc_cov_thresh THEN  1 ELSE  0 END AS coverage from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_one2one' GROUP BY homology_id ";
    my $high_orth = $self->compara_dba->dbc->db_handle->selectall_hashref($query, 'homology_id');
    my $query2 = "SELECT homology_id, CASE WHEN min(perc_cov) >= $perc_cov_thresh THEN  1 ELSE  0 END AS coverage from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_one2many' GROUP BY homology_id ";
    my $high_orth2 = $self->compara_dba->dbc->db_handle->selectall_hashref($query2, 'homology_id');
    my $query3 = "SELECT homology_id, CASE WHEN min(perc_cov) >= $perc_cov_thresh THEN  1 ELSE  0 END AS coverage from homology join homology_member using (homology_id) where method_link_species_set_id = $mlss_id and description = 'ortholog_many2many' GROUP BY homology_id ";
    my $high_orth3 = $self->compara_dba->dbc->db_handle->selectall_hashref($query3, 'homology_id');

    $result_href->{'1to1'} = scalar keys %{$high_orth};
    $result_href->{'1tomany'} = scalar keys %{$high_orth2};
    $result_href->{'manytomany'} = scalar keys %{$high_orth3};
    
    @HCO =($high_orth, $high_orth2, $high_orth3 );

    my @temp_result = (\@HCO, $result_href);
    print Dumper($result_href) if ($self->debug() >1);
    $self->param('coverage',\@temp_result);
}

sub _intersect { 
    my $self = shift @_;
    print "\n _intersect  sub............. :     \n" if $self->debug();
    my ($arrayref1, $arrayref2) = @_;
    my @array1 = @{$arrayref1};
    my @array2 = @{$arrayref2};
    my %array1 = map { $_ => 1 } @array1;
    my @intersect = grep { $array1{$_} } @array2;
    print scalar @intersect, "   \n the size of the intersection \n" if ($self->debug() >1);
    return (\@intersect);
}

sub _deep_hash_merge { 
    my $self = shift @_;
    print "\n deep_hash_merge  sub............. :     \n" if $self->debug();
    my ($hashrefA, $hashrefB) = @_;
    my $c;

    for my $href ($hashrefA, $hashrefB) {

        while (my($key,$val) = each %$href) {

            while (my ($inner_key, $inner_val) = each %$val) {
                $c->{$key}->{$inner_key} = $inner_val;
            }
        }
    }
    print "\n the merged results   : \n" if ($self->debug() >1);
    print Dumper($c) if ($self->debug() > 1);
    return $c;
}
1;
