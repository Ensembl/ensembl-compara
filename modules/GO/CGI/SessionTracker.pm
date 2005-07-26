package GO::CGI::SessionTracker;
use GO::Utils qw(rearrange);
use FreezeThaw qw (freeze thaw);
use FileHandle;

=head1



=cut

sub new {
    my $class = shift;
    my ($session) =
      rearrange([qw(session)], @_);
    my $self = {};
    bless $self, $class;

    my $read_file = new FileHandle;
    my $frozen_session;
    my $session_id = $session->get_param('session_id');
    if ($read_file->open("< sessions/$session_id")) {
      $frozen_session = $read_file->gets;
      $read_file->close;
      chmod 0777, $session_id;
    }
    
    if ($frozen_session) {
      my @object_from_disk = thaw($frozen_session);
      if (@object_from_disk->[0]) {
	$self->{'params'} = @object_from_disk->[0];
      }
    } 
    return $self;
}


=head2 syncronize_session

(is that spelled right?)

  args  -session=>$session
  returns   none

It's anyone's guess what might happen when I call this.

What's SUPPOSED to happen is that any query values of
'override' will be replaced in the SessionTracker object.

The problem is that there's no way to know if the values
in the users query or the users session should be the
current value.  So if you want to replace the ev_code  values
in the session object with those in the query, the query
should have &override=ev_code&ev_code=ISS 

=cut 

sub syncronize_session {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  ## override session values which are overridden

  if ($session->get_param('override')){
    my @overrides = $session->get_param('override');
    foreach my $override (@overrides) {
      if (!$session->get_param($override)) {
	@{$self->{'params'}->{$override}} = '';
      } else {
	@{$self->{'params'}->{$override}} = $session->get_param($override);
      }
    }
  }

  ## Save session to disk.

  my $file = new FileHandle;
  my $session_id = $session->get_param('session_id');
  if ($file->open("> sessions/$session_id")) {
    print $file freeze($self->{'params'});
    $file->close;
  }
  
  ## reset values in current query with session values

  foreach my $key (keys %{$self->{'params'}}) {
    if ($self->{'params'}->{$key} ne '') {
      $session->get_cgi->param(-name=>$key, -values=>$self->{'params'}->{$key});
    } else {
      $session->get_cgi->param(-name=>$key, -value=>'');
    }
  }   
}

1;
