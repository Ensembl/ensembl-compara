package EnsEMBL::Web::Object::Blast;

### Proxiable Object which wraps around the BLAST back end, analogous
### to Object::Gene etc which are wrappers around the Ensembl API

## Developer note:
## The aim is to create an object which can be updated to
## use a different queuing mechanism, without any need to
## change the user interface. Where possible, therefore,
## public methods should accept the same arguments and 
## return the same values

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);
use Bio::Tools::Run::EnsemblSearchMulti;
use EnsEMBL::Web::ExtIndex;
use Data::Dumper;
use IO::Scalar;
use Bio::SeqIO;

our $VERBOSE = 0;

sub caption       { return undef; }
sub short_caption { return 'Blast'; }
sub counts        { return undef; }

#-----------------------------------------------------------------------------

sub adaptor     { return $_[0]->Obj->{'adaptor'}; }

sub submit_query {
### Submits a query to the blast server
### and returns a ticket ID to enable retrieval
  my $self = shift;

  my $adaptor = $self->adaptor;
  my $search_multi = Bio::Tools::Run::EnsemblSearchMulti->new();
  $adaptor && $search_multi->adaptor( $adaptor );
  $search_multi->verbose( $VERBOSE ); # Set to 1 for debug
  foreach my $env( qw( HTTP_X_FORWARDED_FOR REMOTE_ADDR ) ){
    # Log environment variables for tracing users
    if( $ENV{$env} ){ $search_multi->{"_$env"} = $ENV{$env} }
  }

  # Create a new search object
  my $token = $search_multi->token ||
    die( $search_multi->throw("New SearchMulti obj has no token!") );
  my @bits = split( '/', $token );
  my $ticket = pop @bits;
  $VERBOSE && warn( "CREATING BLAST: $ticket [PID=$$ TIME=".
                    (time()-1060600000)."]" );

  ## Add data and configuration to search object
  $self->adaptor->ticket($ticket);
  $self->_process_query($search_multi);
  $self->_process_method($search_multi);
  
  ## Store search object to disk (could be replaced with storage to session/user record)
  $search_multi->store;
  return $ticket;
}

sub get_status {
### Takes an array of ticket IDs and returns a hashref
### containing statuses for each ticket and an overall
### status for the batch (completed or not completed)
  my ($self, @tickets) = @_;
  my $report = {};
  my $runnable;

  foreach my $t (@tickets) {

    my $blast = $self->retrieve_ticket($t);
    my @run_list;
    if ($blast) {
      eval { $blast->_initialise_runnables };
      if ($@) { warn $@; }
      my @A = $blast->runnables($t);
      foreach $runnable (@A) {
        if ($runnable->status eq 'PENDING') {
          $report->{$t} = 'queued';
          $report->{'complete'} = 0;
          $report->{'pending'} = 1;
        }
        elsif ($runnable->status eq 'COMPLETED') {
          $report->{$t} = 'completed';
          $report->{'complete'} = 1;
          my $token = $runnable->token;
          if ($token =~ m#/(\w+)$#) {
            $report->{'run_id'} = $1;
          }
        }
        else {
          # TODO: make this more user-friendly!
          $report->{$t} = $runnable->status;
          $report->{'complete'} = 0;
        }
      }
    }
  }

  return $report;
}

sub run_jobs {
### Run any pending jobs
  my ($self, @tickets) = @_;

  foreach my $t (@tickets) {

    my $blast = $self->retrieve_ticket($t);
    my @run_list;
    if ($blast) {
      eval { $blast->_initialise_runnables };
      if ($@) { warn $@; }
      my @A = $blast->runnables($t);
      foreach my $runnable (@A) {
        if ($runnable->status eq 'PENDING') {
          ## Dispatch this search
          $runnable->status('DISPATCHED');
          push @run_list, $runnable;
        }
        warn "RUNNABLE = ".$runnable->status;
      }
      ## Save changes made so far
      $blast->store;

      ## Now run any pending searches
      foreach my $runnable (@run_list) {
        eval { $runnable->run };
        if ($@) {
          ## TODO: error message
          warn "BLAST RUN ERROR: $@";
        }
        if ($runnable->status eq 'COMPLETED') {
          $runnable->store;
        }
      }
    }
  }
}

sub fetch_coord_systems {
  my $self = shift;

  my $runnable = $self->retrieve_runnable;
  my $species = $runnable->result->database_species;
  my $DBAdaptor = $self->DBConnection->get_databases_species($species, 'core')->{'core'};
  my $coord_systems = {};
  my $CoordSystemAdaptor = $DBAdaptor->get_CoordSystemAdaptor;
  foreach my $CoordSystem( @{$CoordSystemAdaptor->fetch_all} ) {
    my $name = $CoordSystem->name;
    my $rank = $CoordSystem->rank;
    next if $coord_systems->{$name} && $rank > $coord_systems->{$name};
    $coord_systems->{$name} = $rank;
  }
  return $coord_systems;
}

sub retrieve_ticket {
### Retrieves a search result for a given ticket ID
### and returns a search object
  my ($self, $ticket) = @_;
  warn "TICKET $ticket";
  return unless $ticket;
  $VERBOSE && warn( "RETRIEVING BLAST: $ticket [PID=$$ TIME=".
                    (time()-1060600000)."]" );
  my $search_multi;
  eval{
    $search_multi = Bio::Tools::Run::EnsemblSearchMulti->retrieve
      ( $ticket, $self->adaptor ? $self->adaptor : () );
  };
  if( $search_multi ){
    # Check blast integrity
    eval{ $search_multi->runnables };
    $@ || return $search_multi; # Object OK
  }
  my $err = "Cannot retrieve BlastView ticket $ticket";
  $self->problem($err);
  my $msg = "$err: ". ( $@ || 'Unknown' );
  warn( $msg );
  return;
}

sub retrieve_data {
  my ($self, $data_type) = @_;

  my $runnable = $self->retrieve_runnable;
  if ($runnable) {
    my $species = $runnable->result->database_species;

    my $data;
    if ($data_type eq 'hsp') {
      $data = $self->retrieve_hsp;
    }
    elsif ($data_type eq 'hit') {
      $data = $self->retrieve_hit;
    }
    else {
      $data = $self->_retrieve_alignments($runnable);
    }
    return ($species, $data);
  }
  else {
    warn "@@@ No runnable found!";
  }
  return undef;
}

sub retrieve_runnable {
  my $self = shift;

  my $ticket = $self->param('ticket');
  $self->problem("INTERFACE ERROR: no ticket number supplied") unless $ticket;
  my $run_id = $self->param('run_id');
  $self->problem("INTERFACE ERROR: no run ID supplied!") unless $run_id;
  my $blast = $self->retrieve_ticket($ticket);
  return unless $blast;

  my $run_token = $blast->workdir."/".$run_id;
  my( $runnable )= $blast->runnables_like( -token=>$run_token );
  $self->problem("ERROR: Result $run_id not found for ticket $ticket") unless $runnable;
  return $runnable;
}

sub retrieve_hsp {
  my $self = shift;

  my $hsp;
  if( my $hsp_id = $self->param('hsp_id') ){
    eval{ $hsp = Bio::Search::HSP::EnsemblHSP->retrieve($hsp_id, $self->adaptor) };
    $@ and warn( $@ );
    $self->problem("HSP $hsp_id not found for ticket ".$self->param('ticket')) unless $hsp;
  }
  return $hsp;
}

sub retrieve_hit {
  my $self = shift;

  my $hit;
  if( my $hit_id = $self->param('hit_id') ){
    eval{ $hit = Bio::Search::Hit::EnsemblHit->retrieve($hit_id, $self->adaptor) };
    $@ and warn( $@ );
    $self->problem("Hit $hit_id not found for ticket ".$self->param('ticket')) unless $hit;
  }
  return $hit;
}

sub _retrieve_alignments {
  my ($self, $runnable) = @_;

  ## Create sorted alignment [$hit,$hsp] from top NN scoring HSPs
  my $data = [];
  my $result  = $runnable->result;
  my $sortby = $self->param('view_sortby') || 'score';

  my $num_aligns = $self->param('view_numaligns') || 100;
  my $max_aligns  = 10000;
  my $tot_aligns = 0;
  map{ $tot_aligns += $_->num_hsps } $result->hits;
  if ( $num_aligns > $max_aligns ) {
    $num_aligns = $max_aligns if $num_aligns > $max_aligns;
    $num_aligns = $tot_aligns if $num_aligns > $tot_aligns;
  }

  foreach my $hit( $result->hits ){
    push @$data, map{ [$hit,$_] } $hit->hsps;
  }

  if (scalar(@$data) > 0) {

    if (scalar(@$data) > 1) {
      @$data = ( sort{ $b->[1]->$sortby <=> $a->[1]->$sortby }
                       @$data )[0..$num_aligns-1];
    }
  }

  return $data;
}

sub sort_table_values {
  my ($self, $alignments, $coord_systems) = @_;

  my $sort = $self->param('view_sort') || "evalue_dsc";
  my( $sort_by, $direction ) = split( '_', $sort );
  my $sorted = 0; # Whether we have found a valid sort
  foreach my $csname( @$coord_systems ){
    next if $csname ne $sort_by;
    my $scode = sub{
      my( $up, $do ) =
        ( $direction eq 'asc' ?
          ( $a->[1]->genomic_hit($csname)||'', $b->[1]->genomic_hit($csname)||'' ) :
          ( $b->[1]->genomic_hit($csname)||'', $a->[1]->genomic_hit($csname)||'' ) );
      if( $up && $do ){
        return ( 3 * ($up->seq_region_name cmp $do->seq_region_name) +
                 1 * ($up->start           <=> $do->start ) );
      }
      if( $up ){ return -1 }
      if( $do ){ return 1  }
      return 0;
    };
    @$alignments = sort{ &$scode } @$alignments;
    $sorted++;
    last;
  }
  foreach my $stat qw( score evalue pvalue identity length ){
    last if $sorted;
    next if $stat ne $sort_by;
    my $method = $stat;
    if( $stat eq 'identity' ){ $method = 'percent_identity' }
    if ( $direction eq 'asc') {
      @$alignments = sort{ $a->[1]->$method <=> $b->[1]->$method } @$alignments;
    }
    else {
      @$alignments = sort{ $b->[1]->$method <=> $a->[1]->$method } @$alignments;
    }
    $sorted++;
    last;
  }
  return $alignments;
}

sub new_hsp_image {
  my ($self, $alignments) = @_;

  my $runnable = $self->retrieve_runnable;
  my $result = $runnable->result;

  my $bucket = EnsEMBL::Web::Container::HSPContainer->new($result, $alignments);
  my $config = $self->get_imageconfig('hsp_query_plot');
  $config->set_parameters({
       'image_width',      => $self->param('image_width') || 500,
       'slice_number',     => '1|1',
     });
  my $hsp_dc = Bio::EnsEMBL::DrawableContainer->new( $bucket, $config);

  my $image = new EnsEMBL::Web::File::Image( $self->species_defs );
  $image->set_tmp_filename();
  $image->dc = $hsp_dc;
  $image->{'img_map'} = 1;
  return $image;
}

###-------------------------------- PRIVATE METHODS ------------------------------------------

sub _process_query {
### Helper method used by submit_query to turn CGI parameters into a search
### sequence attached to the EnsemblSearchMulti object
  my ($self, $blast) = @_;

  my $changed = 0;

  my $method = $self->param('method');

  my %max_lengths = ( SSAHA   => 50000,
          SSAHA2  => 50000,
          DEFAULT => 200000 );
  my $max_length = $max_lengths{$method} || $max_lengths{DEFAULT};
  my $max_number = 30;

  # Load from file upload
  if( my $fh = $self->param('_uploadfile') ){
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $i = 0;
    while( my $seq = $seq_io->next_seq ){
      if( $i > $max_number ){ last }
      eval{ $blast->add_seq($seq) };
      if( $@ ){ return $@ }
    }
    $changed = 1;
  }
  elsif ( my $id = $self->param('_pfetch_accession') or
         $self->param('_pfetch_retrieve') ){
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    $id || return "Need a sequence ID";
    my $indexer = EnsEMBL::Web::ExtIndex->new( $self->object->species_defs );
    my $seq = join( "", @{$indexer->get_seq_by_id({DB=>"PUBLIC",
                                                   ID=>$id})} );
    if( ! $seq or $seq =~ /^no match/ ){
      $seq = join( "", @{$indexer->get_seq_by_acc({DB=>"PUBLIC",
                                                   ACC=>$id})} );
      if( ! $seq or $seq =~ /^no match/ ){
        return "Sequence ID $id was not found";
      }
    }
    if( $seq !~ /^>/ ){ $seq = ">$id\n".$seq }
    my $fh = IO::Scalar->new(\$seq);
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $bioseq = $seq_io->next_seq;
    eval{ $blast->add_seq($bioseq) };
  }
  elsif ( my $seq = $self->param('_query_sequence') and $self->param('_query_sequence') !~ /^\*\*\*/o ){
    # Load from sequence string
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    $seq =~ s/^\s+//;
    if( $seq !~ /^>/ ){ $seq = ">unnamed\n".$seq }
    my $fh = IO::Scalar->new(\$seq);
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $i = 0;
    while( my $bioseq = $seq_io->next_seq ){
      if( $i > $max_number ){ last }
      eval{ $blast->add_seq($bioseq) };
      if( $@ ){ return $@ }
    }
    $changed = 1;
  }

  #Max sequence length check
  my $max_length_error = 0;
  my @seqs        = ();
  foreach my $seq( $blast->seqs ){
    $seq->length > $max_length ? unshift @seqs, $seq : push @seqs, $seq;
    #warn( ">>> ",$seq->alphabet );
  }

  my $num_seqs = scalar( @seqs );
  $self->param( 'num_sequences',  $num_seqs); # Keep tally

  if( $num_seqs < 1 ){
    return "No query sequences have been entered";
    warn "No query sequences have been entered";
  }

  # Construct the _query_sequence summary
  my $htmpl = qq(
***QUERY INFO: %s %s SEQUENCE\(S\)***\n);

  my $tmpl = qq/
Seq %s: %s (%s letters)%s/;

  my $str = sprintf
    ( $htmpl, $num_seqs, uc( $self->param("query") ) );

  my $i = 0;
  foreach my $seq( @seqs ){
    #    warn( Dumper $qseq );
    my $length_warn = '';
    if( $seq->length > $max_length ){
      $length_warn = " Too long!";
      $max_length_error ++;
    }
    $i++;
    $str .= sprintf
      (
       $tmpl,
       $i, $seq->display_id, $seq->length, $length_warn
      );
  }
  $self->param('_query_sequence', $str );

  if( $num_seqs > $max_number ){
    warn ( "No queries submitted: ".
      "The maximum number of query sequences ($max_number) ".
      "has been exceeded. " );
  }
  if( $max_length_error ){
    warn ( "No queries submitted: ".
      "The maximum length for a single query sequence ".
      "($max_length bp for $method) ".
      "has been exceeded" );
  }

  return;
}

sub _process_method {
### Helper method used by submit_query to set up a search method
### on the EnsemblSearchMulti object
### TODO: will probably need pruning to remove obsolete interface-related code
  my ($self, $blast) = @_;

  my $sp = $self->species_defs->ENSEMBL_PRIMARY_SPECIES;
  my %methods = %{$self->species_defs->get_config($sp, 'ENSEMBL_BLAST_METHODS')||{}};

  my $qt = $self->param('query')        || return "";
  my @sp = $self->param('species');  scalar( @sp ) || return '';
  my $dt = $self->param('database')     || return "";
  my $db = $self->param("database_$dt") || return "";
  my $me = $self->param('method')       || return "Need a method";

  my $changed_qt = $self->param('_changed_query')        ? 1 : 0;
  my $changed_sp = $self->param('_changed_species')      ? 1 : 0;
  my $changed_dt = $self->param('_changed_database')     ? 1 : 0;
  my $changed_db = $self->param("_changed_database_$dt") ? 1 : 0;
  my $changed_me = $self->param('_changed_method')       ? 1 : 0;
  my $changed_se = $self->param('_changed_sensitivity' ) ? 1 : 0;

  # Get current method
  my $method;
  eval{ ( $method ) = $blast->methods };
  if( $@ ){ warn( $@ ) && $self->problem("Ensembl system error") }

  # Only set method if we have a new one
  if( ! $method or $changed_me or $changed_se){

    # Remove existing methods from job
    foreach( $blast->methods ){
      my $id = $_->id;
      eval{ $blast->remove_method($id) };
      if( $@ ){ warn( $@ ) &&  return "Can't remove method $id" }
    }

    # Create a new method object
    eval{ $method = Bio::Tools::Run::Search->new(-workdir=> $blast->workdir(),
             -method=>$methods{$me} ) };
    if( $@ ){ warn( $@ ) &&  return "Can't use $me. Ensembl system error!" }

    # Add the new method
    $method->id( $me );
    eval{ $blast->add_method($method) };
    if( $@ ){ warn( $@ ) &&  return "Can't use $me. Ensembl system error!" }

    # Clean up parameters for this method/sensitivity vs old
    my $sensitivity  = uc( $self->param( 'sensitivity' ) );
    my $params = $method->parameter_options() || {};
    foreach my $param( keys %$params ){
      my $existing_val = $self->param( $param ); #TODO save value?
      next if $sensitivity eq 'CUSTOM' and defined $existing_val;
      my $def = undef;
      if( exists( $params->{$param} ) ){
        if( exists( $params->{$param}->{"default_$sensitivity"} ) ){
          $def = $params->{$param}->{"default_$sensitivity"}
        } elsif( exists( $params->{$param}->{"default"} ) ){
          $def = $params->{$param}->{"default"}
        }
      }
      $self->param($param, $def);
    }

  }

  # Set method priority based on num species and num dbs
  my $num_dbs  = scalar( @sp );
  my $num_seqs = scalar( $blast->seqs );
  my $num_jobs = $num_dbs * $num_seqs;
  my $priority;
  if   ( $num_jobs < 5  ){ $priority = 'offline'  }#'blast_test' }
  elsif( $num_jobs < 15 ){ $priority = 'slow'     }#'blast_test' }
  else                   { $priority = 'basement' }#'blast_test' }
  $method->priority( $priority );

  # Only set databases if species or databases changed
  my %existing_dbs = map{$_, 1} $blast->databases;
  if( scalar( %existing_dbs  ) and
      ! $changed_sp and
      ! $changed_dt and
      ! $changed_db ){
    return 0;
  }

  # Update BLAST
  foreach my $sp( @sp ){
    my $database = $sp.'_'.$db;

    if( $existing_dbs{$database} ){
      delete( $existing_dbs{$database} );
      next;
    }

    eval{ $blast->add_database($database) };
    if( $@ ){ warn( $@ ); return $@; }
  }
  map{ $blast->remove_database($_) } keys %existing_dbs;

  return 0;
}

1;
