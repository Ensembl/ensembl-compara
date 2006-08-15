package EnsEMBL::Web::Wizard::User;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
use Mail::Mailer;

our @ISA = qw(EnsEMBL::Web::Wizard);


sub _init {
  my ($self, $object) = @_;

  ## define fields available to the forms in this wizard
  my %form_fields = (
      'user_id'   => {
          'type'=>'Integer', 
          'label'=>'', 
      },
      'email'     => {
          'type'=>'Email', 
          'label'=>'Email address',
          'required'=>'yes',
      },
      'password'  => {
          'type'=>'Password', 
          'label'=>'Password',
          'required'=>'yes',
      },
      'name'      => {
          'type'=>'String', 
          'label'=>'Your Name', 
          'required'=>'yes',
      },
      'org'       => {
          'type'=>'String', 
          'label'=>'Organisation',
      },
      'mailing'       => {
          'type'=>'SubHeader', 
          'value'=>'Sign me up for the following mailing lists:',
      },
      'ensembl_announce'=> {
          'type'=>'CheckBox', 
          'label'=>'ensembl-announce',
          'notes'=>' (low-volume list used to announce major releases and updates)',
      },
      'ensembl_dev'=> {
          'type'=>'CheckBox', 
          'label'=>'ensembl-dev',
          'notes'=>' (high volume mailing list for Ensembl development, open to all)',
      },
      'bm_name'   => {
          'type'=>'String', 
          'label'=>'Name of this bookmark', 
          'required'=>'yes',
      },
      'bm_url'   => {
          'type'=>'String', 
          'label'=>'URL', 
      },
      'bookmarks' => {
          'type' => 'MultiSelect',
          'label'=> 'Current bookmarks',
          'values'=>'bookmarks',
      },
      'pub_groups'  => {
          'type' => 'MultiSelect',
          'label'=> 'Subscriptions to public groups',
          'values'=>'pub_groups',
      },
      'res_groups'  => {
          'type' => 'MultiSelect',
          'label'=> 'Subscriptions to restricted groups',
          'values'=>'res_groups',
      },
      'members'  => {
          'type' => 'MultiSelect',
          'label'=> 'Members',
          'values'=>'members',
      },
  );

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
      ## login nodes - generally free access
      'details'      => {
                      'form' => 1,
                      'title' => 'Please enter your details',
                      'input_fields'  => [qw(name email password org mailing ensembl_announce ensembl_dev)],
                      'restricted' => 0,
      },
      'preview'      => {
                      'form' => 1,
                      'title' => 'Please check your details',
                      'show_fields'  => [qw(name email password org ensembl_announce ensembl_dev)],
                      'pass_fields'  => [qw(name email password org ensembl_announce ensembl_dev)],
                      'back' => 1,
                      'restricted' => 0,
      },
      'login'       => {
                      'form' => 1,
                      'input_fields'  => [qw(email password)],
                      'restricted' => 0,
      },
      'lost_password' => {
                      'form' => 1,
                      'input_fields'  => [qw(email)],
                      'restricted' => 0,
      },
      'acknowledge'   => {'page' => 1, 'restricted' => 0},
      'check_new'     => {'button'=> 'Register', 'restricted' => 0},
      'check_old'     => {'button'=>'Reset', 'restricted' => 0},
      'validate'      => {'button'=>'Login', 'restricted' => 0},
      'save'          => {'restricted' => 0},
      'send_link'     => {'restricted' => 0},

      ## account nodes - restricted access
      'new_password' => {
                      'form' => 1,
                      'input_fields'  => [qw(password)],
                      'restricted' => 1,
      },
      'reset_password'=> {'button'=>'Save', 'restricted' => 1},

      'accountview'   => {'title' => 'Account Details',
                        'page' => 1,
                        'restricted' => 1},
      'name_bookmark' => {
                      'form' => 1,
                      'title' => 'Save bookmark',
                      'show_fields'  => [qw(bm_url)],
                      'pass_fields'  => [qw(bm_url user_id)],
                      'input_fields'  => [qw(bm_name)],
                      'restricted' => 1
      },
      'save_bookmark' => {'button'=>'Save', 'restricted' => 1},
      'select_bookmarks' => {
                      'form' => 1,
                      'title' => 'Select bookmarks to delete',
                      'input_fields'  => [qw(bookmarks)],
                      'restricted' => 1
      },
      'delete_bookmarks' => {'button'=>'Delete', 'restricted' => 1},
      'show_groups' => {
                      'form' => 1,
                      'title' => 'Unsubscribe',
                      'input_fields'  => [qw(pub_groups res_groups)],
                      'restricted' => 1
      },
      'delete_groups' => {'button'=>'Remove', 'restricted' => 1},
      'select_members' => {
                      'form' => 1,  
                      'input_fields' => [qw(members)],
                      'restricted' => 1
      },
      'delete_members' => {'button'=>'Delete', 'restricted' => 1},
      'list_members' => {
                      'page' => 1,
                      'restricted' => 1
      },
);

  my $help_email = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;

  my %message = (
    'duplicate' => "Sorry, we appear to have a user with this email address already. Please try again.",
    'invalid' => "Sorry, the email address and password did not match a valid account. Please try again.",
    'not_found' => "Sorry, that email address is not in our database. Please try again.",
    'save_failed' => 'Sorry, there was a problem saving your details. Please try again later.',
    'save_ok' => "Thank you for registering with Ensembl!",
    'update_ok' => "Thank you - your changes have been saved.",
    'send_failed' => qq(Sorry, there was a problem sending your new password. Please contact <a href="mailto:$help_email">$help_email</a> for assistance.),
    'send_ok' => "Your new password has been sent to your registered email address.",
    'no_delete' => 'Sorry, there was a problem deleting your bookmarks. Please try again later.',
    'log_back' => 'Please log back into Ensembl using your new password.',
);

  ## get useful data from object
  my $user_id = $object->get_user_id;
warn "User $user_id";
  my @bookmarks = @{ $object->get_bookmarks($user_id) };
  my @bm_values;
  foreach my $bookmark (@bookmarks) {
    my $bm_id   = $$bookmark{'bm_id'};
    my $bm_name = $$bookmark{'bm_name'};
    my $bm_url  = $$bookmark{'bm_url'};
    push @bm_values, {'value'=>$bm_id,'name'=>"$bm_name ($bm_url)"};
  }

  ## get available groups
  my @all_groups = @{ $object->get_all_groups }; 
  my ($pub_values, $priv_values, $res_values);
  foreach my $group (@all_groups) {
    my $group_id  = $$group{'group_id'};
    my $title     = $$group{'title'};
    my $type      = $$group{'type'};
    if ($type eq 'public') {
      push @$pub_values, {'value'=>$group_id,'name'=>"$title"};
    }
    elsif ($type eq 'private') {
      push @$priv_values, {'value'=>$group_id,'name'=>"$title"};
    }
    elsif ($type eq 'restricted') {
      push @$res_values, {'value'=>$group_id,'name'=>"$title"};
    }
  }
=pod
  ## get group members
  my @mem_values;
  my $group_name = $object->param('group');
  my @members = @{ $object->get_members($group_name) };
  foreach my $member (@members) {
    my $mem_id      = $$member{'user_id'};
    my $mem_name    = $$member{'name'};
    my $mem_email   = $$member{'email'};
    my $mem_status  = $$member{'status'};
    my $label = "$mem_name ($mem_email)";
    $label .= ' <strong>Administrator</strong>' if $mem_status eq 'admin';
    push @mem_values, {'value'=>$mem_id,'name'=>$label};
  }
=cut
  my $details   = $object->get_user_by_id($user_id);

  my $data = {
    'details'     => $details,
    'bookmarks'   => \@bm_values,
    'pub_groups'  => $pub_values,
    'priv_groups' => $priv_values,
    'res_groups'  => $res_values,
    #'members'     => \@mem_values,
  };

  return [$data, \%form_fields, \%all_nodes, \%message];
}


##----------------------- UTILITIES --------------------------------------

sub _mail {
  my ($self, $to, $from, $reply, $subject, $body) = @_;

  my $mailer = new Mail::Mailer 'smtp', Server => "mail.sanger.ac.uk";
  $mailer->open({
                'To'      => $to,
                'From'    => $from,
                'Reply-To'=> $reply,
                'Subject' => $subject,
                });
  print $mailer $body;
  $mailer->close();
  return 1;
}


## ---------------------- ACCOUNT MANAGEMENT METHODS ----------------------

sub accountview { 
  ## doesn't do anything wizardy, just displays some info and links
  return 1;
}

sub login {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'login', "/$species/$script", 'post' );

  $wizard->simple_form('login', $form, $object, 'input');

  return $form;
}

sub validate {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check on these details
  my ($is_ok, $not_ok, $result);
  if (my $code = $object->param('code')) {
    $result = $object->get_user_by_code($code);
    $is_ok  = 'new_password';
    $not_ok = 'lost_password';
    $parameter{'code'} = $code;
  }
  else {
    $result = $object->validate_user($object->param('email'), $object->param('password'));
    $is_ok  = 'accountview';
    $not_ok = 'login';
  }

  ## select response based on results
  if ($result && $$result{'user_id'}) {  
    $parameter{'node'} = 'set_cookie';
    $parameter{'next_node'} = $is_ok; 
    $parameter{'user_id'} = $$result{'user_id'}; ## next node will set cookie
  }
  else {
    $parameter{'node'} = $not_ok; ## return to input node
    $parameter{'error'} = 1;
    if ($result) {
      $parameter{'feedback'} = $$result{'error'};
    }
    else {
      $parameter{'feedback'} = 'invalid';
    }
  }

  return \%parameter;
}

sub set_cookie {
  my ($self, $object) = @_;
  my %parameter; 

  $parameter{'set_cookie'}  = $object->param('user_id'); ## sets a cookie, i.e. logs in
  $parameter{'node'}        = $object->param('next_node'); 
  $parameter{'error'}       = 0;

  return \%parameter;
}

sub details {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'details';
 
  my $id = $object->get_user_id;
  my @fields = qw(name email);
  if ($id) {
    my $details = $object->get_user_by_id($id);
    $object->param('name', $$details{'name'});
    $object->param('email', $$details{'email'});
    $object->param('org', $$details{'org'});
  }
  else {
    push(@fields, 'password');
  }
  push(@fields, 'org', 'mailing', 'ensembl_announce', 'ensembl_dev');
 
  my $form = EnsEMBL::Web::Form->new( 'details', "/$species/$script", 'post' );

  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object, \@fields);
  $wizard->add_buttons($node, $form, $object);


  return $form;
}

sub preview {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'preview', "/$species/$script", 'post' );

  $wizard->simple_form('preview', $form, $object, 'output');

  return $form;
}

sub check_new {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check to see if this user already exists
  my %details = %{$object->get_user_by_email($object->param('email'))};
  my $user_exists = $details{'user_id'} ? 1 : 0;

  ## select response based on results
  if ($user_exists) {  
    $parameter{'node'} = 'details'; ## return to input node
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'duplicate';
    $parameter{'name'}              = $object->param('name');
    $parameter{'email'}             = $object->param('email');
    $parameter{'org'}               = $object->param('org');
    $parameter{'ensembl_announce'}  = $object->param('ensembl_announce');
    $parameter{'ensembl_dev'}       = $object->param('ensembl_dev');
  }
  else {
    $parameter{'node'} = 'save'; ## if genuine new user, save details
    ## pass form parameters to next node
    $parameter{'name'}              = $object->param('name');
    $parameter{'email'}             = $object->param('email');
    $parameter{'password'}          = $object->param('password');
    $parameter{'org'}               = $object->param('org');
    $parameter{'ensembl_announce'}  = $object->param('ensembl_announce');
    $parameter{'ensembl_dev'}       = $object->param('ensembl_dev');
  }

  return \%parameter;
}

sub save {
  my ($self, $object) = @_;
  my %parameter; 

  my $id = $object->get_user_id; ## add user ID if we're updating a record
  my $record = $self->create_record($object);
  if ($id) {
    $$record{'user_id'} = $id; 
  }
  my $result = $object->save_user($record);
  if ($result) {  
    ## send out mailing list subscriptions
    my $message;
    if ($object->param('ensembl_announce') || $object->param('ensembl_dev')) {
      #my $to = 'majordomo@ebi.ac.uk';
      my $to    = 'ap5@sanger.ac.uk';
      my $from  = $object->param('email');
      my $reply = $object->param('email');
      my $subject = 'Sign-up from Ensembl Account Registration';
      if ($object->param('ensembl_announce')) {
        $message = qq(subscribe ensembl-announce);
        $self->_mail($to, $from, $reply, $subject, $message);
      }
      if ($object->param('ensembl_dev')) {
        $message = qq(subscribe ensembl-dev);
        $self->_mail($to, $from, $reply, $subject, $message);
      }
    }

    ## take to account page
    $parameter{'node'} = 'accountview';
    $parameter{'error'} = 0;
    if ($id) {
      $parameter{'feedback'} = 'update_ok'; 
    }
    else {
      $parameter{'feedback'} = 'save_ok'; 
    }
    $parameter{'set_cookie'} = $result; ## next node will set cookie
  }
  else {
    $parameter{'node'} = 'register'; 
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
  }

  return \%parameter;
}

sub new_password {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
 
  $wizard->field('password', 'label', 'New password'); 
  my $node = 'new_password';
  my $form = EnsEMBL::Web::Form->new( $node, "/$species/$script", 'post' );

  $wizard->add_widgets($node, $form, $object);
  if (my $code = $object->param('code')) {
    $form->add_element('type'=>'Hidden', 'name'=>'code', 'value'=>$code);
  }
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub save_password {
  my ($self, $object) = @_;
  my %parameter; 

  my ($next, $id);
  if (my $code = $object->param('code')) {
    $next = 'logout';
    my $details = $object->get_user_by_code($code);
    $id = $$details{'user_id'};
  }
  else {
    $next = 'accountview';
    $id = $object->get_user_id;
  }

  my $record = $self->create_record($object);
  $parameter{'node'} = $next;
  if ($id) {
    $$record{'user_id'} = $id; 
    my $result = $object->set_password($record);
    $parameter{'error'} = 0;
    $parameter{'feedback'} = 'update_ok'; 
  }
  else {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
  }

  return \%parameter;
}

sub lost_password {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'lost_password', "/$species/$script", 'post' );

  $wizard->add_widgets('lost_password', $form, $object);
  $wizard->add_buttons('lost_password', $form, $object);

  return $form;
} 

sub check_old {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check to see if this user already exists
  my %details = %{$object->get_user_by_email($object->param('email'))};
  my $user_exists = $details{'user_id'} ? 1 : 0;

  ## select response based on results
  if (!$user_exists) {  
    $parameter{'node'} = 'lost_password'; ## return to input node
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'not_found';
  }
  else {
    $parameter{'error'} = 0;
    $parameter{'user_id'} = $details{'user_id'};
    $parameter{'node'} = 'send_link'; ## reset password
  }

  return \%parameter;
}

sub send_link {
  my ($self, $object) = @_;
  my %parameter; 

  ## reset password
  my $id = $object->param('user_id');
  if ($id) {
    my $record = $self->create_record($object);
    $$record{'reset'}   = 'auto'; 
    my $code = $object->set_password($record);

    ## send password link to user
    my $server  = $ENV{'SERVER_NAME'};
    my $port    = $ENV{'SERVER_PORT'};
    $server = $server.':'.$port if $port != 80; ## include non-default ports only in URL
    my %details =  %{ $object->get_user_by_id($id) }; 
    my $email = $details{'email'};
    my $name  = $details{'name'};

    if ($email) {
      my $message = qq(Dear $name

We have received a lost password request from your Ensembl account. Please click on the link below to reset your Ensembl password:

http://$server/common/reset_password?code=$code

Regards

The Ensembl Web Team
);

      $self->_mail($email, 'webmaster@ensembl.org', 'webmaster@ensembl.org',
                  'www.ensembl.org - Lost Password', $message);
  
      ## forward to next node
      $parameter{'node'} = 'acknowledge'; 
      $parameter{'error'} = 0;
    }
    else {
      $parameter{'node'} = 'lost_password'; ## return to input node
      $parameter{'error'} = 1;
      $parameter{'feedback'} = 'send_failed';
    }
  }
  else {
    $parameter{'node'} = 'lost_password'; ## return to input node
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'send_failed';
  }


  return \%parameter;
}

sub acknowledge {
  ## doesn't do anything wizardy!
}

sub logout {
  my ($self, $object) = @_;
  my %parameter; 

  $parameter{'set_cookie'}  = 0; ## sets a blank cookie, i.e. logs out
  $parameter{'exit'}        = 'user_login'; 
  $parameter{'feedback'}    = 'log_back';
  $parameter{'error'}       = 0;

  return \%parameter;
}

sub select_members {
  my ($self, $object) = @_;

}

sub delete_members {
  my ($self, $object) = @_;

}

sub list_members {
  ## doesn't do anything wizardy!
}

#------------------ USER CUSTOMISATION METHODS -------------------------

sub name_bookmark {
  my ($self, $object) = @_;

  ## set CGI variables, since input is from link, not form
  my $user_id   = $object->get_user_id; 
  my $url       = $ENV{'HTTP_REFERER'};
  my $server    = $ENV{'SERVER_NAME'};
  (my $bm_name = $url) =~ s#http://$server(:[0-9]+)?##;
  $object->param('bm_url', $url); 
  $object->param('bm_name', $bm_name); 
  $object->param('user_id', $user_id); 
 
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'name_bookmark', "/$species/$script", 'post' );

  my $node = 'name_bookmark';
  $wizard->add_title($node, $form, $object);
  $wizard->show_fields($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub save_bookmark {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  
  my %parameter;
  $parameter{'node'} = 'accountview';

  my $user_id = $object->param('user_id'); 
  my $bm_name = $object->param('bm_name'); 
  my $url     = $object->param('bm_url'); 
  if ($user_id && $url) {

    ## save bookmark
    my $result = $object->save_bookmark($user_id, $url, $bm_name);

    ## set response
    unless ($result) {
      $parameter{'error'} = 1;
      $parameter{'feedback'} = 'no_bookmark';
    }
    return \%parameter;
  }

  warn "No bookmark :(";
  $parameter{'error'} = 1;
  $parameter{'feedback'} = 'no_bookmark';

  return \%parameter;
}

sub select_bookmarks {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $form = EnsEMBL::Web::Form->new( 'select_bookmarks', "/$species/$script", 'post' );

  $wizard->simple_form('select_bookmarks', $form, $object, 'input');

  return $form;
}

sub delete_bookmarks {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};

  my %parameter;
  $parameter{'node'} = 'accountview';

  ## get list of bookmarks to delete
  my @deletes;
  if (ref($object->param('bookmarks')) eq 'ARRAY') {
    @deletes = @{ $object->param('bookmarks') };
  }
  else {
    push @deletes, $object->param('bookmarks');
  }
  my $result = $object->delete_bookmarks(\@deletes);
  unless ($result) {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'no_delete';
  }
  return \%parameter;
}

sub show_groups {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $form = EnsEMBL::Web::Form->new( 'show_groups', "/$species/$script", 'post' );

  $wizard->simple_form('show_groups', $form, $object, 'input');

  return $form;
}

1;

__END__
                                                                                
=head1 Ensembl::Web::Wizard

=head2 SYNOPSIS

=head2 DESCRIPTION

=head2 METHODS                                                                                
=head3 B<method_name>
                                                                                
Description:

Arguments:     
                                                                                
Returns:  

=head2 BUGS AND LIMITATIONS
                                                                                
=head2 AUTHOR
                                                                                
Anne Parker, Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut                                                                  

                                                                                
