#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. 

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;

use Bio::Tools::Run::Phylo::PAML::Codeml;
use Bio::EnsEMBL::Hive;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'codeml_parameters_href'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{ha} = $self->{'comparaDBA'}->get_HomologyAdaptor;

  $self->get_params($self->parameters);
  my $homology_id = $self->input_id;
  if ($homology_id =~ /ids/) { # it's the job_array-based input_id
    my $ids = eval($homology_id);
    my @homologies;
    foreach my $id (@{$ids->{ids}}) {
      my $homology = $self->{ha}->fetch_by_dbID($id);
      push @homologies, $homology;
    }
    $self->{'homology'} = \@homologies;
  } else {
    my @homologies;
    push @homologies, $self->{ha}->fetch_by_dbID($homology_id);
    $self->{'homology'} = \@homologies;
  }

  return 1 if($self->{'homology'});
  return 0;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);
  
  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  if (defined $params->{'dNdS_analysis_data_id'}) {
    my $analysis_data_id = $params->{'dNdS_analysis_data_id'};
    my $ada = $self->db->get_AnalysisDataAdaptor;
    my $codeml_parameters_hashref = eval($ada->fetch_by_dbID($analysis_data_id));
    if (defined $codeml_parameters_hashref) {
      $self->{'codeml_parameters_href'} = $codeml_parameters_hashref;
    }
  }
  
  return;

}


sub run
{
  my $self = shift;

  foreach my $homology (@{$self->{'homology'}}) {
    $self->calc_genetic_distance($homology);
  }
  return 1;
}


sub write_output {
  my $self = shift;

  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor;
  foreach my $homology (@{$self->{'homology'}}) {
    $homologyDBA->update_genetic_distance($homology);
  }
  return 1;
}


##########################################
#
# internal methods
#
##########################################

sub calc_genetic_distance
{
  my $self = shift;
  my $homology = shift;

  #print("use codeml to get genetic distance of homology\n");
  $homology->print_homology if ($self->debug);
  
  # second argument will change selenocyteine TGA codons to NNN
  my $aln = $homology->get_SimpleAlign("cdna", 1);

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  
  my $codeml = new Bio::Tools::Run::Phylo::PAML::Codeml();
  my $possible_exe = $self->analysis->program_file;
  if(defined $possible_exe) {
    print("Using executable at ${possible_exe}\n") if $self->debug;
    $codeml->executable($possible_exe);
  }
  #$codeml->save_tempfiles(1);
  if (defined $self->{'codeml_parameters_href'}) {
    my %params = %{$self->{'codeml_parameters_href'}};
    foreach my $key (keys %params) {
      $codeml->set_parameter($key,$params{$key});
    }
  }
  $codeml->alignment($aln);
  if (0 != $aln->{_special_codeml_icode}) {
    $codeml->set_parameter("icode",$aln->{_special_codeml_icode})
  }
  my ($rc,$parser) = $codeml->run();
  if($rc == 0) {
    print_simple_align($aln, 80);
    print("codeml error : ", $codeml->error_string, "\n");
    my $collapsed_aln = $aln->remove_gaps;
    $collapsed_aln->gap_char('N'); # Ns are not used either, so default to gaps
    if (0 == $collapsed_aln->remove_gaps->length) {
      # $self->input_job->update_status('FAILED');
      # $self->throw("Codeml : The pairwise alignment is all gapped");
      warn("Codeml : The pairwise alignment is all gapped or Ns");
      return $homology;
    }
    warn("There was an error running codeml");
    return $homology;
  }
  my $result;
  eval{ $result = $parser->next_result };
  unless( $result ){
    #If there is an error check if it was something which is produced
    #by strange alignments (where identity/similarity is very very low)
    my $error = $@;
    if( $error ){ 
      warn( "${error}\n" );
      warn( "Parser failed" );
      if($error->isa('Bio::Root::NotImplemented')) {
        warn("Caught a NotImplemented error. Ignoring as this can be generated from bad alignments \n");
      }
      else {
        die;
      }
    }
    return $homology;
  }
  my $MLmatrix = $result->get_MLmatrix();

  #print "n = ", $MLmatrix->[0]->[1]->{'N'},"\n";
  #print "s = ", $MLmatrix->[0]->[1]->{'S'},"\n";
  #print "t = ", $MLmatrix->[0]->[1]->{'t'},"\n";
  #print "lnL = ", $MLmatrix->[0]->[1]->{'lnL'},"\n";
  #print "Ka = ", $MLmatrix->[0]->[1]->{'dN'},"\n";
  #print "Ks = ", $MLmatrix->[0]->[1]->{'dS'},"\n";
  #print "Ka/Ks = ", $MLmatrix->[0]->[1]->{'omega'},"\n";

  $homology->n($MLmatrix->[0]->[1]->{'N'});
  $homology->s($MLmatrix->[0]->[1]->{'S'});
  $homology->dn($MLmatrix->[0]->[1]->{'dN'});
  $homology->ds($MLmatrix->[0]->[1]->{'dS'});
  $homology->lnl($MLmatrix->[0]->[1]->{'lnL'});

  # We check that the sequences differ to avoid the dS=0.000N0 codeml
  # problem - there is one case in the DB with dS=0.00110 that is
  # clearly a 0 because dS*S is way lower than 1
  if ( (1 > ((($homology->{_ds})*$homology->{_s})+0.1)) || (1 > ((($homology->{_dn})*$homology->{_n})+0.1)) ) {
    # Bioperl version
    eval {require Bio::Align::DNAStatistics;};
    unless ($@) {
      my $stats = new Bio::Align::DNAStatistics;
      if($stats->can('calc_KaKs_pair')) {
        my ($seq1id,$seq2id) = map { $_->display_id } $aln->each_seq;
        my $results = $stats->calc_KaKs_pair($aln, $seq1id, $seq2id);
        my $counting_method_dn = $results->[0]{D_n};
        my $counting_method_ds = $results->[0]{D_s};

        # We want to be strict in the counting of dS, because sometimes
        # the counting method gives half a (dS*S) where codeml doesn't. So
        # we only change to dS=0 when strictly 0 in the counting method
        if (0 == abs($counting_method_ds) && (1 > ((($homology->{_ds})*$homology->{_s})+0.1))) {
          $homology->ds(0);       # dS strictly 0
        }
        # Also for dN, although this happens very very rarely (seen once so far)
        if (0 == abs($counting_method_dn) && (1 > ((($homology->{_dn})*$homology->{_n})+0.1))) {
          $homology->dn(0);       # dN strictly 0
        }
      }
    }
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return $homology;
}

sub print_simple_align
{
  my $alignment = shift;
  my $aaPerLine = shift;
  $aaPerLine=40 unless($aaPerLine and $aaPerLine > 0);

  my ($seq1, $seq2)  = $alignment->each_seq;
  my $seqStr1 = "|".$seq1->seq().'|';
  my $seqStr2 = "|".$seq2->seq().'|';

  my $enddiff = length($seqStr1) - length($seqStr2);
  while($enddiff>0) { $seqStr2 .= " "; $enddiff--; }
  while($enddiff<0) { $seqStr1 .= " "; $enddiff++; }

  my $label1 = sprintf("%40s : ", $seq1->id);
  my $label2 = sprintf("%40s : ", "");
  my $label3 = sprintf("%40s : ", $seq2->id);

  my $line2 = "";
  for(my $x=0; $x<length($seqStr1); $x++) {
    if(substr($seqStr1,$x,1) eq substr($seqStr2, $x,1)) { $line2.='|'; } else { $line2.=' '; }
  }

  my $offset=0;
  my $numLines = (length($seqStr1) / $aaPerLine);
  while($numLines>0) {
    printf("$label1 %s\n", substr($seqStr1,$offset,$aaPerLine));
    printf("$label2 %s\n", substr($line2,$offset,$aaPerLine));
    printf("$label3 %s\n", substr($seqStr2,$offset,$aaPerLine));
    print("\n\n");
    $offset+=$aaPerLine;
    $numLines--;
  }
}

1;
