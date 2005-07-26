#!/usr/local/bin/perl
#
=head1 usage

see usage for GO::CGI::HTML;

=cut
package GO::CGI::Session;

use GO::AppHandle;
use GO::Utils qw(rearrange);
use FileHandle;
use DirHandle;
use FreezeThaw qw (freeze thaw);
use strict;
use Data::Dumper;

=head2 new

-args -out  Filehandle;
      -q    CGI,
      -data GO::Model::Graph

returns  GO::CGI::Session;

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my ($q, $out, $data, $no_update) =
	rearrange([qw(q out data no_update)], @_);

    $self->{'cgi'} = $q;
    $self->{'out'} = $out;
    $self->{'data'} = $data;
    # $self->{'queries'} is now what holds the data for performing
    # a query.  The CGI values will no longer be directly used.
    # As such, $self->{'queries'}->{n} is what will be returned by get_param
    # and get_param_hash.

    unless ($no_update) {
      $self->__clear_sessions;
      $self->__load_session;
      $self->__synchronize_session;
      $self->__save_session;
    }


    return $self;
    
}

=head2 cleanQueryValues

args     none
returns  none

Removes queries from the list of the current session
when someone clicks the collapser icon.

=cut


sub cleanQueryValues {
    my $self = shift;

    warn ('cleanQueryValues is obsolete');
  }

sub __synchronize_session {
  my $self = shift;
  my $q = $self->get_cgi;
  
  if ($self->get_cgi->param('idfile')) {
      my $file = $self->get_cgi->param('idfile');
      my $dataline;
      my @data;
      while (defined($dataline = <$file>)) {
	  my @a = split "\t", $dataline;
	  foreach my $a(@a) {
	      $a =~ s/\s*//g;
	      push @data, $a;
	  }
      }
      $self->__set_param(-field=>'query',
				-values=>\@data);
  }

  $self->{'params'}->{'current_query'} = {};

  foreach my $param (keys %{$self->{'cgi'}->Vars}) {
    my @values = split ("\0", $self->{'cgi'}->Vars->{$param});
    $self->__set_param(-query=>'current_query',
		       -field=>$param,
		       -values=>\@values);
  }

  $self->__map_forward_old_params;



  my $action = $self->get_param('action', 'current_query');

  if (!defined($self->{'params'}->{'1'})) {
    $self->{'params'}->{'1'} = {};
  }
  $self->__trim_queries;

  my @auto_long_term_storage = (
				'threshhold',
				'show_gp_dag',
				'show_gp_xrefs',
				'show_gp_gps',	
			       );
  foreach my $alts(@auto_long_term_storage) {
    if ($self->get_param($alts, 'current_query')) {
      $self->__copy_fields(-fields=>[$alts]);
    }
  }
  my @multi_long_term_storage = (
				 'selected_xrefs'
				);
  foreach my $mlts(@multi_long_term_storage) {
    if ($self->get_param($mlts, 'current_query')) {
      $self->__append_fields(-fields=>[$mlts],
			    -query=>'1');
    }
  }
  $self->__delete_fields(-fields=>\@multi_long_term_storage,
			 -query=>'current_query');
  my %trim_multi_long_term_storage->{'unselected_xrefs'} = 'selected_xrefs';
  foreach my $tmlts(keys %trim_multi_long_term_storage) {
    if ($self->get_param($tmlts, 'current_query')) {
      $self->__remove_values(-field=>$tmlts,
			     -to_field=>%trim_multi_long_term_storage->{$tmlts},
			     -query=>'current_query',
			     -to_query=>'1'
			    );
    }
  }


  my @auto_replace = ('advanced_query',
		      'open_0',
		      'open_1',
		      'search_constraint',
		     );
  foreach my $replace(@auto_replace) {
    if ($self->get_param($replace)) {
      $self->__copy_fields(-fields=>[$replace]);
    }
  }
  my @copy_or_delete = (
			'auto_wild_cards'
		     );
  foreach my $cod(@copy_or_delete) {
    $self->__copy_or_delete(-fields=>[$cod]);
  }



  if ($action eq 'minus_node') {
    $self->__append_field(-field=>'query', -to_field=>'closed');
    $self->__remove_values(-field=>'query', 
			  -to_field=>'open_0');
    $self->__remove_values(-field=>'query', 
			  -to_field=>'open_1');
    $self->__delete_fields(-query=>'current_query',
			   -fields=>['query']);
  } elsif ($action eq 'plus_node') {
    $self->__remove_values(-field=>'query',
			   -to_field=>'closed');
    if ($self->get_param('depth') == 0) {
      $self->__append_field(-field=>'query',
			    -to_field=>'open_0');
    } else {
      $self->__append_field(-field=>'query',
			    -to_field=>'open_1');      
    }
    $self->__delete_fields(-query=>'current_query',
			   -fields=>['query']);
  } elsif ($action eq 'query') {
    $self->__copy_fields(-fields=>['ev_code', 'species_db', 'auto_wild_cards', 'search_constraint']);
  } elsif ($action eq 'replace_tree') {
    $self->__delete_fields(-query=>'1',
			   -fields=>['open_0', 'open_1', 'closed']);
    if ($self->get_param('depth') == 0) {
      $self->__append_field(-field=>'query',
			    -to_field=>'open_0');
    } else {
      $self->__append_field(-field=>'query',
			    -to_field=>'open_1');      
    }
    $self->__delete_fields(-query=>'current_query',
			   -fields=>['query']);
  } else {
    $self->__copy_fields(-fields=>['ev_code', 'species_db']);
    $self->__delete_fields(-query=>'current_query',
			     -fields=>['ev_code', 'species_db']);
    my @new_values;
    foreach my $value(@{$self->get_param_values(-field=>'query', -query=>'current_query') || []}) {
#      if ($value =~ m/^\d+$/) {
	push @new_values, $value;
#      }
    }
    $self->__append_param(-field=>'open_0',
		       -values=>\@new_values);

  }

  if ($self->get_param('view') eq 'tree') {
    my $query = $self->get_param('query');
    $self->__delete_fields(-query=>'current_query',
			   -fields=>['query']);
    my $root_node = $self->get_param('ROOT_NODE') || $self->apph->get_root_term->public_acc || 'GO:0003673';
    if ($self->__has_value(-field=>'closed', -value=>$root_node)) {
#      $self->__append_param(-query=>'1',
#			    -field=>'open_0',
#			    -values=>[$root_node]);
    } else {
      $self->__append_param(-query=>'1',
			    -field=>'open_1',
			    -values=>[$root_node]);
    }
  } elsif ($self->get_param('view') eq 'details') {
    if ($self->get_param('search_constraint') eq 'gp') {
      
    } else {
      $self->__copy_fields(-fields=>['ev_code', 'species_db']);
      $self->__delete_fields(-query=>'current_query',
			     -fields=>['ev_code', 'species_db', 'open_0']);
      $self->__append_field(-field=>'query',
			    -query=>'current_query',
			    -to_query=>'current_query',
			    -to_field=>'open_0'); 
    }
  } elsif  ($self->get_param('view') eq 'query') {
    $self->__copy_fields(-fields=>['ev_code', 'species_db', 'advanced_query']);
    $self->__delete_fields(-query=>'current_query',
			   -fields=>['ev_code', 'species_db']);
  }
  if (!defined($self->get_param('session_id', '1'))) {
    $self->__append_param(-query=>'1',
			  -field=>'session_id',
			  -values=>[$self->__create_session_id]);
  }


}


sub __trim_queries {
  my $self = shift;

  my @new_queries;
  
  my $queries = $self->get_param_values(-field=>'query',
				   -query=>'current_query');

  foreach my $query (@$queries) {
    my @query = split '[\n\t]', $query;
    foreach my $q(@query) {
      $q =~ s/^\s*(.*?)\s*$/$1/;
#      $q =~  s/^GO:0*//;
      push @new_queries, $q;
    }
  }
  $self->__set_param(-field=>'query',
		     -query=>'current_query',
		     -values=>\@new_queries);

}

sub __map_forward_old_params {
  my $self = shift;
  

  if (($self->get_param_values(-query=>'current_query',
				  -field=>'minus_node'))) {
    my $value = $self->get_param('minus_node', 'current_query');
    $self->__append_param(-query=>'current_query',
			  -field=>'query',
			  -values=>[$value]);
    $self->__append_param(-query=>'current_query',
			  -field=>'action',
			  -values=>['minus_node']);
  }
  if (($self->get_param_values(-query=>'current_query',
				  -field=>'plus_node'))) {
    my $value = $self->get_param('plus_node', 'current_query');
    $self->__append_param(-query=>'current_query',
			  -field=>'query',
			  -values=>[$value]);
    $self->__append_param(-query=>'current_query',
			  -field=>'action',
			  -values=>['plus_node']);
  }
}

sub __remove_values {
  my $self = shift;
  my ($field, $to_field, $query, $to_query) =
    rearrange([qw(field to_field query to_query)], @_);
  
  if (!defined($to_field)) {
    $to_field = $field;
  }
  if (!defined($query)) {
    $query = 'current_query';
  }
  if (!defined($to_query)) {
    $to_query = '1';
  }
   my @new_list;
  my $values = $self->get_param_values(-query=>$to_query,
				  -field=>$to_field);
  my $val = $self->get_param_values(-query=>$query,
			     -field=>$field);
  my $is_in;
  foreach my $v (@$values) {
    $is_in = 0;
    foreach my $value (@$val) {
      if ($v eq $value) {
	$is_in = 1;
      }
    }
    if (!$is_in) {
      push @new_list, $v;
    }
  }
  $self->__set_param(-query=>$to_query,
		     -field=>$to_field,
		     -values=>\@new_list);
}

sub __delete_fields {
  my $self = shift;
  my ($query, $fields) =
    rearrange([qw(query fields)], @_);
  
  if (!defined($query)) {
    $query = 'current_query';
  }

  foreach my $field(@$fields) {
    $self->__set_param(-query=>$query,
		       -field=>$field,
		       -values=>undef);
  }		    
}

sub __copy_fields {
  my $self = shift;
  my ($fields) =
    rearrange([qw(fields)], @_);

  foreach my $field(@$fields) {
    if ($self->get_param($field, 'current_query')) {
      my $values = $self->get_param_values(-query=>'current_query',
				      -field=>$field);
      
      my @v = thaw freeze $values;
      my $v = @v->[0];
      $self->__set_param(-query=>'1', -field=>$field, -values=>$v);
    }
  }
}


sub __copy_or_delete {
  my $self = shift;
  my ($fields) =
    rearrange([qw(fields)], @_);

  foreach my $field(@$fields) {
    if ($self->get_param($field, 'current_query')) {
      $self->__copy_fields(-fields=>[$field]);
    } else {
      $self->__set_param(-query=>'1', -field=>$field, -values=>[]);
    }
  }
}

sub __append_fields {
  my $self = shift;
  my ($fields) =
    rearrange([qw(fields)], @_);
  
  foreach my $field(@$fields) {
    $self->__append_field(-field=>$field);
  }

}

sub __append_field {
  my $self = shift;
  my ($field, $to_field, $query, $to_query) =
    rearrange([qw(field to_field query to_query)], @_);
  
  if (!defined($to_field)) {
    $to_field = $field;
  }
  if (!defined($query)) {
    $query = 'current_query';
  }
  if (!defined($to_query)) {
    $to_query = '1';
  }

  my $values = $self->get_param_values(-query=>$query, -field=>$field);
  if (defined($self->get_param_values(-query=>$to_query, -field=>$to_field))) {
      my $is_in == 0;
      foreach my $value(@$values) {
	$is_in = 0;
	foreach my $v (@{$self->get_param_values(-query=>$to_query, -field=>$to_field)}) {
	  if ($v eq $value) {
	    $is_in = 1;
	  }
	}
	if (!$is_in) {
	  push (@{$self->get_param_values(-query=>$to_query, -field=>$to_field)}, $value);
	}
      }
    } else {
      my @v = thaw freeze $values;
      my $v = @v->[0];
      $self->__set_param(-query=>'1', -field=>$to_field, -values=>$v);
    }
  
}

sub __append_param {
  my $self = shift;
  my ($query, $field, $values) =
    rearrange([qw(query field values)], @_);
  
  if (!defined($query)) {
    $query = 1;
  }

  if (defined($self->get_param_values(-query=>$query, -field=>$field))) {
    my $is_in == 0;
    foreach my $value(@$values) {
      $is_in = 0;
      foreach my $v (@{$self->get_param_values(-query=>$query, -field=>$field)}) {
	if ($v eq $value) {
	  $is_in = 1;
	}
      }
      if (!$is_in) {
	push (@{$self->get_param_values(-query=>$query, -field=>$field)}, $value);
      }
    }
  } else {
    $self->__set_param(-query=>$query, -field=>$field, -values=>$values);
  }
}


sub __set_param {
  my $self = shift;
  my ($query, $field, $values) =
    rearrange([qw(query field values)], @_);

  if (!defined($query)) {
    $query = 1;
  }
  $self->{'params'}->{$query}->{$field} = $values;
}

sub get_param_values {
  my $self = shift;
  my ($field, $query) =
    rearrange([qw(field query)], @_);
  
  if (!defined($query)) {
    $query = 1;
  }
  
  return $self->{'params'}->{$query}->{$field};
}

sub __remove_acc_from_field {
  my $self = shift;
  my ($acc, $field) =
    rearrange([qw(acc field)], @_);
    
  my $q = $self->get_cgi;


  my @value_list;
  my @q_l = split "\0", $self->get_param_hash->{$field};
  foreach my $value(@q_l) {
    $value =~ s/^\s*(.*?)\s*$/$1/;
#    $value =~ s/^GO:?//;
#    $value =~ s/^0*//;

    if ($value ne $acc) {
      push @value_list, $value;
    }
  }
  if (scalar(@value_list) > 0) { 
    $q->param(-name=>$field, -values=>\@value_list);
  } else {
    $q->param(-name=>$field, -values=>'');
  }
}

sub __add_values_to_field {
  my $self = shift;
  my ($values, $field) =
    rearrange([qw(values field)], @_);

  my $q = $self->get_cgi;
  
  my @new_values = split "\0", $self->get_param_hash->{$field};
  push @$values, @new_values;
  $q->param(-name=>$field, -values=>\@new_values);

}

sub __has_value {
  my $self = shift;
  my ($field, $value) =
    rearrange([qw(field value)], @_);

  my @new_values = split "\0", $self->get_param_hash->{$field};
  foreach my $v(@new_values) {
    if ($v == $value) {return 1};
  }
  return 0;
}

sub __is_inside {
    my $self = shift;
    my ($acc, $array) = @_;

    foreach my $node(@$array) {
	if ($acc == $node) {
	    return 1;
	}
    }
    return 0;
}

=head2 makeTermlistFromBatch

args     none
returns  none

Adds the "hit" nodes of a text search to the sessions 
query list, so that  the tree can be collpased/expanded.

=cut

sub makeTermlistFromBatch {
  my $self = shift;
  my $q = $self->get_cgi;
  my @term_list;
  if ($self->get_param('batch')) {
    @term_list = split("\n", $self->get_param('batch'));
  }
  $q->param(-name=>'query', -values=>\@term_list);    
}

=head2 makeTermlistFromSearch

args     term_list
returns  none

Adds the "hit" nodes of a text search to the sessions 
query list, so that  the tree can be collpased/expanded.

=cut

sub makeTermlistFromSearch  {
    my $self = shift;
    my ($term_list) =
	rearrange([qw(term_list)], @_);
    
    my $q = $self->get_cgi;
    
    $q->delete('query');
    my @queries;
    foreach my $term(@$term_list) {
      push @queries, $term->acc;
    }
    $q->param(-name=>'query', -values=>\@queries);    
}

=head2 get_cgi

args     none
returns  CGI;

=cut

sub get_cgi {
    my $self = shift;

    return $self->{'cgi'};
}

=head2 get_param

 Usage: my $dbname = $session->get_param("dbname");

will first check the CGI paramaters; if not set, it will look for
per-user-session saved settings; otherwise returns system defaults

=cut

sub get_param {
    my $self = shift;
    my $pname = shift;
    my $query = shift;

    if (defined($query)) {
      if (defined ($self->get_param_values(-query=>'current_query',
				      -field=>$pname))){
	eval {
	  return @{$self->get_param_values(-query=>$query,
					   -field=>$pname)}->[0];
	};
      } else {
	return undef;
      }
    }
    elsif (defined ($self->get_param_values(-query=>'current_query',
				    -field=>$pname))) {
      return @{$self->get_param_values(-query=>'current_query',
				  -field=>$pname)}->[0];
    }
    elsif (defined ($self->get_param_values(-query=>'1',
				    -field=>$pname))) {
      return @{$self->get_param_values(-query=>'1',
				  -field=>$pname)}->[0];
    }
    elsif (defined($self->{user_settings}->{$pname})) {
	return $self->{user_settings}->{$pname};
    }
    elsif (defined($ENV{uc("GO_$pname")})) {
	return $ENV{uc("GO_$pname")};
    }
    elsif (defined($self->default_val($pname))) {
	return $self->default_val($pname);
    }
    else {
	return ;
    }
}



sub default_val {
    my $self = shift;
    my $pname = shift;
    my %defaults =
      (
       "dbname"=>"go",
       "dbhost"=>"sin.lbl.gov",
       "view"=>"tree"
      );
    return $defaults{$pname};
}

sub apph {
    my $self = shift;
    if (!$self->{'apph'}) {
	my $dbname = $self->get_param("dbname");
	my $dbhost = $self->get_param("dbhost");
	$self->{'apph'} =
	  GO::AppHandle->connect(-dbname=>$dbname, -dbhost=>$dbhost); 
    }
    return $self->{'apph'};
}

=head2 set_cgi

args     CGI;
returns  none


=cut

sub set_cgi {
    my $self = shift;
    my $cgi = shift;

    $self->{'cgi'} = $cgi;
}

=head2 get_param_hash

args     none
returns  hash table of params

If a value is given for $hash (which query you want -
currently "current_query" or "1") only values from that
query will be returned.  Otherwise, cgi values have priority,
followed by current_query, followed by '1' 

NOTE:  For legacy reasons, this returns multiple results
  as a \0 seperated string rather than as an array, so to
  loop thru the results do:

foreach my $value(split("\0", $session->get_param_hash->{'query'})) {}

=cut

sub get_param_hash {
    my $self = shift;
    my $hash = shift;
    my $params = shift;
    
    #if (!defined($params)) {
    #  $params = {};
    #}

    if ($hash) {
      foreach my $param(keys %{$self->{'params'}->{$hash}}) {
	if (!defined($params->{$param})) {
	  foreach my $value(@{$self->{'params'}->{$hash}->{$param}}) {
	    if ($params->{$param}) {
	      $params->{$param} .= "\0$value";
	    } else {
	      $params->{$param} .= "$value";
	    }
	  }
	}
      }
      return $params;	  
    } else {
      $params = $self->get_param_hash('current_query', $params);
      $params = $self->get_param_hash('1', $params);
    }
    return $params;	  
}

=head2 set_output

args     Filehandle
returns  none

=cut

sub set_output{
    my $self = shift;
    my $out = shift;
    
    $self->{'out'} = $out;

}

=head2 get_output

args     none
returns  Filehandle

=cut


sub get_output{
    my $self = shift;
    
    return $self->{'out'};     
}

=head2 set_data

    args     GO::Model::Graph;
returns  none

=cut

sub set_data{
    my $self = shift;
    my $data = shift;
    
    $self->{'data'} = $data;

}

=head2 get_data

args     none
returns  GO::Model::Graph;

=cut

sub get_data{
    my $self = shift;
    
    return $self->{'data'};     
}

=head2 get_session_settings_urlstring

args     optional:  array_ref of query_values to pass along
returns  string

    returns a url string with the values of all the parameters
    specified in @settings_to_pass_along in the familiar &param=value
    format.

=cut

sub get_session_settings_urlstring {
    my $self = shift;
    my $settings_to_pass_along = shift;

    if (!$settings_to_pass_along) {
       $settings_to_pass_along = 
	[
	 'session_id',
	 'ev_code',
	 'auto_wild_cards',
	 'species_db',
	 'search_descriptions',
	 'advanced_query'
	];
    }
    my $setting_pass_alongs = "";
    foreach my $value (@$settings_to_pass_along) {
	foreach my $param (split ('\0', %{$self->get_param_hash}->{$value})) {
	    $setting_pass_alongs .= "&$value=$param";
	}
    }
    return $setting_pass_alongs;
}

=head2 get_session_querylist_urlstring

args     none
returns  string

    much the same as get_session_settings_urlstring except
    its specialized for the query param

=cut

sub get_session_querylist_urlstring {
    my $self = shift;

    my $query_extension = "";
    foreach my $query_value(split ('\0', %{$self->get_param_hash}->{'query'})) {
	$query_extension .= "&query=$query_value";
    }
    foreach my $query_value(split ('\0', %{$self->get_param_hash}->{'closed'})) {
	$query_extension .= "&closed=$query_value";
    }
    return $query_extension;
}


=head2 sync_session_from_file

args     none
returns  none

saves session to file named $session->get_param('session_id')
If there is no session_id a new one is created.

The idea is that we only save things which need to be transferred
between screens to file.  This includes ev_code and species_id from
the detail view for when you make your next choice from the
tree view.  Everything else is passed in the urlstring - that 
way people can bookmark stuff.

=cut


sub sync_session_from_file {
  my $self = shift;
  require FileHandle;
  require GO::CGI::SessionTracker;

  if ($self->get_param('session_id')) {
    my $file_name = $self->get_param('session_id');
    my $file = new FileHandle;
    my $st = new GO::CGI::SessionTracker(-session=>$self);
    $st->syncronize_session(-session=>$self);
  } else {
    $self->__create_session_id;
    $self->sync_session_from_file;
  }
}

sub __create_session_id {
  my $self = shift;
  
  my $session_id = "";
  
  $session_id = int(rand(10000));
  $session_id .= time;
		
  my $q = $self->get_cgi;
  $q->param(-name=>'session_id', -value=>$session_id);

}

sub __dump_session_values {
  my $self = shift;
  
  


}


=head2 get_session_from_file

args     none
returns  none

gets session from file named $session->get_param('session_id')

=cut


sub get_session_from_file {

}


sub __equal_accs {
    my $self = shift;
    my ($acc1, $acc2) = @_;
    
    if ($acc1 =~ m/^GO:?/) {
    } else {
	$acc1 = $self->__make_go_from_acc($acc1);
    }
    if ($acc2 =~ m/^GO:?/) {
    } else {
	$acc2 = $self->__make_go_from_acc($acc2);
    }
    if ($acc1 eq $acc2) {
	return 1;
    } else {
	return 0;
    }

}



sub __make_go_from_acc {
    my $self = shift;
    my $acc = shift;
    
    return sprintf "GO:%07d", $acc;
}

sub __clear_sessions {
  my $self = shift;

  ## Clean out sessions in here
  my $session_dir = $self->get_param('session_dir') || 'sessions';

  ## Clean out temporary images in here.
  my $tmp_images = $self->get_param('tmp_image_dir_relative_to_docroot') || 'tmp_images';
  my $html_dir = $self->get_param('html_dir') || "../docs";
  my $tmp_image_dir = "$html_dir/$tmp_images";

  my $time = time;
  my $max_sessions = $self->get_param('MAX_SESSIONS') || 200;
  my $session_timeout = $self->get_param('SESSION_TIMEOUT') || 7200;

  foreach my $dir($session_dir, $tmp_image_dir) {
    my $dh = new DirHandle($dir);
    if ((scalar split ('\n', `ls $dir`)) > $max_sessions) {
      while (my $ses = $dh->read) {
	my @stat = lstat("$dir/$ses");
	my $a = @stat->[9];
	if ($time - $a > $session_timeout ) {
	    print "Content-type:text/html\n\n";
	    print "Time: $time A: $a<br>";
	  eval {
	    if ($ses ne '.' && $ses ne '..' && $ses ne 'data') {
	      `rm -rf $dir/$ses`;
	      my $data_dir = $self->get_param('data_dir');
	      my $command = "rm -rf $data_dir/$ses"."_blast";
	      `$command`;
	    }
	  };
	}
      }
    }
  }
}

sub __load_session {
  my $self = shift;
  my $session_id = shift;
  my $session_dir = $self->get_param('session_dir') || 'sessions';
  my $read_file = new FileHandle;
  my $frozen_session;
  unless ($session_id) {
    $session_id = $self->get_cgi->Vars->{'session_id'};
  }
  my $read_file = new FileHandle;
  my $file;
  if ($read_file->open("< $session_dir/$session_id")) {
    my @lines = $read_file->getlines;
    foreach my $line (@lines) {
      $file .= $line;
    }
  }
  if ($file) {
    chmod 0777, $session_id;
    my $VAR1;
    eval $file;
    $self->{'params'} = $VAR1;
  }

}

sub __save_params {
  my $self = shift;
  my ($query, $params) =
	rearrange([qw(query params)], @_);

  require "GO/CGI/Session.pm";

  my $session_id = $self->get_param('session_id');
  my $new_session = GO::CGI::Session->new(-no_update=>1);
  $new_session->__load_session($session_id);

  foreach my $param (@$params) {
    my $values = $self->get_param_values(-query=>$query,
					 -field=>$param);
    $new_session->__set_param(-query=>$query,
			      -field=>$param,
			      -values=>$values);
  }
  $new_session->__save_session;
}

sub __save_session {
  my $self = shift;
  my $session_dir = $self->get_param('session_dir') || 'sessions';
  require Data::Dumper;
  ## Save session to disk.
  my $file = new FileHandle;
  my $session_id = $self->get_param('session_id');
  if ($file->open("> $session_dir/$session_id")) {
    print $file Dumper($self->{'params'});
    $file->close;
  }
}

sub save_to_disk {
    my $self = shift;
    my $data = shift;
    my $name = shift;
    require DirHandle;

    my $session_id = $self->get_param('session_id');

    my $job_file = int(rand(10000));
    my $key_dir = $session_id."_keys";
    my $session_id = $self->get_param('session_id');
    if (!new DirHandle("sessions/$key_dir")) {
	mkdir("sessions/$key_dir");
    }
    my $file = new FileHandle;
    my %seq_hash;
    if ($file->open("> sessions/$key_dir/$job_file")) {
	$file->print($data);
	$file->close;
    }
    return \%seq_hash;
}

sub bootstrap_tree_view {
  my $self = shift;
  my $graph = $self->get_data;
  require "GO/Model/TreeIterator.pm";

  
  my $nit = GO::Model::TreeIterator->new($graph);
  $nit->set_bootstrap_mode;
  
  my @new_open_0;
  my $root_node = $self->get_param('ROOT_NODE') || $self->apph->get_root_term->public_acc || 'GO:0003673';

  if ($self->get_param_values(-field=>'open_0')) {
    foreach my $value (@{$self->get_param_values(-field=>'open_0')}) {
      if (scalar(split ',', $value) == 1 &&
	  $value ne $root_node) {
	
	while (my $ni = $nit->next_node_instance) {
	  my $new_acc;
	  if ($value =~ m/^(\d*){1}$/) {
	    if ($ni->term->acc == $value) {
	      foreach my $v(@{$nit->get_current_path}) {
		$new_acc .= $v.",";
	      }
	    }
	  } else {
	    if ($ni->term->public_acc eq $value) {
	      foreach my $v(@{$nit->get_current_path}) {
		$new_acc .= $v.",";
	      }
	    }
	  }	    
	  chop $new_acc;
	  push @new_open_0, $new_acc;
	}
	$nit->reset_cursor;
      } else {
	push @new_open_0, $value;
      }
    }
  }
  $self->__set_param(-field=>'open_0',
		     -query=>'1',
		     -values=>\@new_open_0);
}

1;
