package EnsEMBL::Web::DBSQL::BlastAdaptor;

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;
use EnsEMBL::Web::SpeciesDefs;
#use EnsEMBL::Web::Object::BlastRequest;

use vars qw($STATUS_PENDING $STATUS_RUNNING $STATUS_COMPLETE $STATUS_PARSED);

BEGIN {
  $STATUS_PENDING  = 0;
  $STATUS_RUNNING  = 1;
  $STATUS_COMPLETE = 2;
  $STATUS_PARSED   = 3;
}

sub new {
  my ($class, $DB) = @_;
  my $self = ref($DB) ? $DB : {};
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}

sub create_sequence {
  my ($self, $parameters) = @_;
  my $sequence = $parameters->{'sequence'};
  my $species = $parameters->{'species'};
  my $job_id = $parameters->{'job_id'};
  my $sql = qq(
     INSERT INTO sequence SET
       sequence = '$sequence',
       species  = '$species',
       job_id   = '$job_id'
     ;
  );
  my $sth = $self->db->prepare($sql);
  my $result = $sth->execute();
}

sub create_ticket {
  my ($self, $parameters) = @_;
  my $ticket = $parameters->{'ticket'};
  my $sql = qq(
    INSERT INTO job SET
     ticket='$ticket', 
     created_at=CURRENT_TIMESTAMP 
    ;
  );
  my $sth = $self->db->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id($result);
}

sub create_hsp_and_alignments {
  my ($self, $parameters) = @_;
  my $hsp = $parameters->{'hsp'};

  my $id = $self->create_hsp($parameters);
  $hsp->id($id);

  if ($hsp->alignments) {
    my @alignments = @{ $hsp->alignments };
    foreach my $alignment (@alignments) {
      $self->create_alignment({'alignment' => $alignment, 'hsp' => $hsp });
    }
  }

}

sub create_hsp {
  my ($self, $parameters) = @_;
  my $hsp = $parameters->{'hsp'};
  my $job = $parameters->{'job'};

  my $job_id        = $job->id;
  my $type          = $hsp->type;
  my $chromosome    = $hsp->chromosome;
  my $probability   = $hsp->probability;
  my $score         = $hsp->score;
  my $start         = $hsp->start;
  my $end           = $hsp->end;
  my $reading_frame = $hsp->reading_frame;

  my $sql = qq(
    INSERT INTO hsp SET
     job_id='$job_id',
     hsp_type='$type',
     chromosome='$chromosome',
     probability='$probability',
     score='$score',
     base_start='$start',
     base_end='$end', 
     reading_frame='$reading_frame'
    ;
  );
  my $sth = $self->db->prepare($sql);
  my $result = $sth->execute();
  return $self->last_inserted_id($result);
} 

sub create_alignment {
  my ($self, $parameters) = @_;
  my $alignment = $parameters->{'alignment'};
  my $hsp = $parameters->{'hsp'};

  my $hsp_id        = $hsp->id;
  my $chromosome    = $alignment->chromosome;
  my $probability   = $alignment->probability;
  my $score         = $alignment->score;
  my $start_query   = $alignment->query_start;
  my $end_query     = $alignment->query_end;
  my $start_subject = $alignment->subject_start;
  my $end_subject   = $alignment->subject_end;
  my $identities    = $alignment->identities;
  my $positives     = $alignment->positives;
  my $reading_frame = $alignment->reading_frame;
  my $display       = $alignment->display;
  my $cigar         = $alignment->cigar_string;

  my $sql = qq(
    INSERT INTO alignment SET
     hsp_id='$hsp_id',
     chromosome='$chromosome',
     probability='$probability',
     score='$score',
     query_start='$start_query',
     query_end='$end_query', 
     subject_start='$start_subject',
     subject_end='$end_subject',
     identities='$identities',
     positives='$positives',
     reading_frame='$reading_frame',
     display='$display',
     cigar='$cigar' 
    ;
  );
  my $sth = $self->db->prepare($sql);
  my $result = $sth->execute();
}

sub last_inserted_id {
  my ($self, $result) = @_;
  if ($result) {
    my $sql = "SELECT LAST_INSERT_ID()";
    my $T = $self->db->selectall_arrayref($sql);
    return '' unless $T;
    my @A = @{$T->[0]}[0];
    $result = $A[0];
  }
  return $result;
}

sub queue_length {
  my $self = shift;
  my $sql = qq(
    SELECT id FROM job WHERE status='$STATUS_PENDING';
  ); 
  my $results = $self->db->selectall_arrayref($sql);
  return $results;
}

sub wait_time {
  my $self = shift;
  my $sql = qq(
    SELECT 
	UNIX_TIMESTAMP(created_at),
	UNIX_TIMESTAMP(modified_at)
    FROM job 
    WHERE status='$STATUS_RUNNING'
    ORDER BY modified_at DESC LIMIT 5;
  ); 
  my @results = @{ $self->db->selectall_arrayref($sql) };
  my $count = 0;
  my $diff = 0;
  foreach my $record (@results) {
    my $created = $record->[0];
    my $modified = $record->[1];
    $diff = ($modified - $created);
    $count++;
  } 
  if ($count == 0) {
    return -1;
  }
  return ($diff / $count);
}

sub running_jobs {
  my $self = shift;
  my $sql = qq(
    SELECT id FROM job WHERE status='$STATUS_RUNNING';
  ); 
  my $results = $self->db->selectall_arrayref($sql);
  return $results;
}

sub fetch_species {
    my ($self, $release_id) = @_;
    my $results = {};

    return {} unless $self->db;

    my $sql;
    if ($release_id && $release_id ne 'all') {
        $sql = qq(
            SELECT
                s.species_id    as species_id,
                s.name          as species_name
            FROM
                species s,
                release_species x
            WHERE   s.species_id = x.species_id
            AND     x.release_id = $release_id
            AND     x.assembly_code != ''
            ORDER BY species_name ASC
        );
    } else {
        $sql = qq(
            SELECT
                s.species_id    as species_id,
                s.name          as species_name
            FROM
                species s
            ORDER BY species_name ASC
        );
    }

    my $T = $self->db->selectall_arrayref($sql);
    return {} unless $T;
    for (my $i=0; $i<scalar(@$T);$i++) {
        my @array = @{$T->[$i]};
        $$results{$array[0]} = $array[1];
    }
    return $results;
}

sub set_pending_status_for_job {
  my ($self, $id) = @_;
  $self->set_status_for_job($STATUS_PENDING, $id);
}

sub set_running_status_for_job {
  my ($self, $id) = @_;
  $self->set_status_for_job($STATUS_RUNNING, $id);
}

sub set_complete_status_for_job {
  my ($self, $id) = @_;
  $self->set_status_for_job($STATUS_COMPLETE, $id);
}

sub set_parsed_status_for_job {
  my ($self, $id) = @_;
  $self->set_status_for_job($STATUS_PARSED, $id);
}

sub set_status_for_job {
  my ($self, $status, $id) = @_;
  my $sql = "UPDATE job SET status='$status' where ID='$id'";
  my $sth = $self->db->prepare($sql);
  my $result = $sth->execute();
}

sub pending_jobs {
  my $self = shift;
  return $self->jobs_with_status($STATUS_PENDING); 
}

sub completed_jobs {
  my $self = shift;
  return $self->jobs_with_status($STATUS_COMPLETE); 
}

sub parsed_jobs {
  my $self = shift;
  return $self->jobs_with_status($STATUS_PARSED); 
}

sub jobs_with_status {

  ## If this SQL request changes, don't forget to update
  ## EnsEMBL::Web::Object::BlastRequest::new_from_database too.

  my ($self, $status) = @_;
  my @jobs = (); 
  my $sql = "
    SELECT 
      job.id, job.ticket, sequence.sequence, sequence.species, job.status
     FROM job
     LEFT JOIN sequence
     ON (job.id = sequence.job_id)
     WHERE 
      status='$status'
     ORDER BY job.created_at ASC 
    ;"; 

  warn "Jobs with status: $status: " . $self->db;
  my @results = @{ $self->db->selectall_arrayref($sql) };
  
  foreach my $record (@results) {
    my $request = EnsEMBL::Web::Object::BlastRequest->new_from_database($record);
    push @jobs, $request; 
  } 
  
  return @jobs;
}

sub job_with_ticket {
  my ($self, $ticket) = @_;
  my @jobs = (); 
  warn "SQL TICKET: " . $ticket;
  my $sql = "
    SELECT 
      job.id, job.ticket, sequence.sequence, sequence.species, job.status
     FROM job
     LEFT JOIN sequence
     ON (job.id = sequence.job_id)
     WHERE 
      ticket='$ticket'
    ;"; 

  my @results = @{ $self->db->selectall_arrayref($sql) };
  warn $sql;
  if (@results) {
    warn "SQL RESULT: " . $results[0];
    return EnsEMBL::Web::Object::BlastRequest->new_from_database($results[0]);
  } else {
    return 0;
  }
}

sub status_pending {
  return $STATUS_PENDING;
}

sub status_running {
  return $STATUS_RUNNING;
}  

sub status_complete {
  return $STATUS_COMPLETE;
}

sub status_parsed {
  return $STATUS_PARSED;
}


1;
