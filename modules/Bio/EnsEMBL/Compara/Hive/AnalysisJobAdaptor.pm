package Bio::EnsEMBL::Compara::Hive::AnalysisJobAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Hive::Worker;
use Bio::EnsEMBL::Compara::Hive::AnalysisJob;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Sys::Hostname;
use Data::UUID;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Subset
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID {
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_by_claim_analysis
  Arg [1]    : string job_claim (the UUID used to claim jobs)
  Arg [2]    : int analysis_id  
  Example    : $jobs = $adaptor->fetch_by_claim_analysis('c6658fde-64ab-4088-8526-2e960bd5dd60',208);
  Description: Returns a list of jobs for a claim id
  Returntype : Bio::EnsEMBL::Compara::Hive::AnalysisJob
  Exceptions : thrown if claim_id or analysis_id is not defined
  Caller     : general
=cut

sub fetch_by_claim_analysis {
  my ($self,$claim,$analysis_id) = @_;

  $self->throw("fetch_by_claim_analysis must have claim ID") unless($claim);
  $self->throw("fetch_by_claim_analysis must have analysis_id") unless($analysis_id);
  my $constraint = "a.job_claim='$claim' AND a.analysis_id='$analysis_id'";
  return $self->_generic_fetch($constraint);
}


=head2 fetch_all

  Arg        : None
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}



#
# INTERNAL METHODS
#
###################

=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch

=cut
  
sub _generic_fetch {
  my ($self, $constraint, $join) = @_;
  
  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());
  
  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;
        
        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      } 
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }
      
  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) { 
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;  

  print STDOUT $sql,"\n";

  return $self->_objs_from_sth($sth);
}

sub _tables {
  my $self = shift;

  return (['analysis_job', 'a']);
}

sub _columns {
  my $self = shift;

  return qw (a.analysis_job_id  
             a.input_analysis_job_id
             a.analysis_id	      
             a.input_id 
             a.job_claim  
             a.hive_id	      
             a.status 
             a.retry_count          
             a.completed
             a.result
            );
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @jobs = ();

  while ($sth->fetch()) {
    my $job = new Bio::EnsEMBL::Compara::Hive::AnalysisJob;

    $job->dbID($column{'analysis_job_id'});
    $job->analysis_id($column{'analysis_id'});
    $job->input_id($column{'input_id'});
    $job->job_claim($column{'job_claim'});
    $job->hive_id($column{'hive_id'});
    $job->status($column{'status'});
    $job->retry_count($column{'retry_count'});
    $job->completed($column{'completed'});
    $job->result($column{'result'});
    $job->adaptor($self);

    push @jobs, $job;    
  }
  $sth->finish;
  
  return \@jobs
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;
  return '';
}


#
# STORE / UPDATE METHODS
#
################

=head2 update_status

  Arg [1]    : $analysis_id
  Example    :
  Description:
  Returntype : Bio::EnsEMBL::Compara::Hive::Worker
  Exceptions :
  Caller     :

=cut

sub update_status {
  my ($self,$job) = @_;

  my $sql = "UPDATE analysis_job ".
            " SET status='".$job->status."' ";
  $sql .= " ,completed=now(), result=1" if($job->status eq 'DONE');
  $sql .= " WHERE analysis_job_id='".$job->dbID."' ";
  
  my $sth = $self->prepare($sql);
  $sth->execute();
  $sth->finish;
}

=head2 store_out_files
  Arg [1]    : Bio::EnsEMBL::Compar::Hive::AnalysisJob $job
  Example    :
  Description: if files are non-zero size, will update DB
  Returntype : 
  Exceptions :
  Caller     :
=cut

sub store_out_files {
  my ($self,$job) = @_;

  return unless($job and ($job->stdout_file or $job->stderr_file));

  my $sql = "INSERT INTO analysis_job_files ".
            " SET analysis_job_id='".$job->dbID."' ";
  $sql .= " ,stdout_file='".$job->stdout_file."' "  if($job->stdout_file);
  $sql .= " ,stderr_file='".$job->stderr_file."' "  if($job->stderr_file);

  my $sth = $self->prepare($sql);
  $sth->execute();
  $sth->finish;
}


sub create_new_job {
  my ($self, @args) = @_;

  return undef unless(scalar @args);
  
  my ($input_id, $analysis_id, $input_analysis_job_id, $blocked) =
     $self->_rearrange([qw(INPUT_ID ANALYSIS_ID input_job_id BLOCK )], @args);
 
  $input_analysis_job_id=0 unless($input_analysis_job_id);
  throw("must define input_id") unless($input_id);
  throw("must define analysis_id") unless($analysis_id);
  
  my $sql = "INSERT ignore into analysis_job ".
            " SET input_id=\"$input_id\" ".
            " ,input_analysis_job_id='$input_analysis_job_id' ".
            " ,analysis_id='$analysis_id' ";
  $sql .= " ,status='BLOCKED', job_claim='BLOCKED'" if($blocked);

  my $sth = $self->prepare($sql);
  $sth->execute();
  my $dbID = $sth->{'mysql_insertid'};
  $sth->finish;

  return $dbID;
}


sub claim_jobs_for_worker {
  my $self     = shift;
  my $worker   = shift;

  throw("must define worker") unless($worker);

  my $ug    = new Data::UUID;
  my $uuid  = $ug->create();
  my $claim = $ug->to_string( $uuid );
  print("claiming jobs with uuid $claim\n");

  my $sql = "UPDATE analysis_job SET job_claim='$claim'".
            " , hive_id='". $worker->hive_id ."'".
            " , status='CLAIMED'".
            " WHERE job_claim='' ".
            " AND analysis_id='" .$worker->analysis->dbID. "'".
            " LIMIT " . $worker->batch_size;

  print("$sql\n");            
  my $sth = $self->prepare($sql);
  $sth->execute();
  $sth->finish;

  return $claim;
}

1;


