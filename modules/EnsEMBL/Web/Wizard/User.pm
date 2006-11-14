package EnsEMBL::Web::Wizard::User;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object::Group;
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::User::Record;
use Mail::Mailer;
use CGI;

our @ISA = qw(EnsEMBL::Web::Wizard);


sub _init {
  my ($self, $object) = @_;

  my $expiry =  86400 * 3; ## expiry period for temporary server-set passwords, in seconds
  my $exp_text = '3 days'; ## expiry period in words (used in emails, etc.)

  my $webgroup_id = $object->param('webgroup_id');
  my @group_types = (
      {'value'=>'open', 'name'=>'Open - anyone can join and get instant access to group settings'}, 
      {'value'=>'restricted', 'name'=>'Restricted - membership must be approved by an administrator'}, 
      {'value'=>'private', 'name'=>'Private - membership by invitation only'},
  );

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
          'label'=>'New Password',
          'required'=>'yes',
      },
      'confirm_password'  => {
          'type'=>'Password', 
          'label'=>'Confirm Password',
          'required'=>'yes',
      },
      'expiry'   => {
          'type'=>'Constant', 
          'value'=>$expiry, 
      },
      'exp_text'   => {
          'type'=>'Constant', 
          'value'=>$exp_text, 
      },
      'name'      => {
          'type'=>'String', 
          'label'=>'Your Name', 
          'required'=>'yes',
      },
      'group_name'      => {
          'type'=>'String', 
          'label'=>'Group name', 
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
      'group_private_check'=> {
          'type'=>'CheckBox', 
          'label'=>'Private',
          'notes'=>'Private group',
      },
      'group_public_check'=> {
          'type'=>'CheckBox', 
          'label'=>'Public',
          'notes'=>'Public group',
      },
      'group_open_check'=> {
          'type'=>'CheckBox', 
          'label'=>'Open',
          'notes'=>'Open group',
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
          'class' => 'formblock', ## long text, so checkboxes need to be on separate lines
      },
      'config_name'   => {
          'type'=>'String', 
          'label'=>'Name of this configuration', 
          'required'=>'yes',
      },
      'script'   => {
          'type'=>'String', 
          'label'=>'Script configured', 
      },
      'configs' => {
          'type' => 'MultiSelect',
          'label'=> 'Saved configurations',
          'values'=>'configs',
      },
      'groups' => {
          'type' => 'MultiSelect',
      },
      'webgroup_id'   => {
          'type'=>'Integer', 
          'label'=>'', 
      },
      'group_name'   => {
          'type'=>'String', 
          'label'=>'Group name', 
      },
      'group_blurb'   => {
          'type'=>'Text', 
          'label'=>'Description of group', 
      },
      'group_type' => {
          'type' => 'DropDown',
          'values' => 'group_types',
      },
  );

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
      'enter_details'      => {
                      'form' => 1,
                      'title' => 'Please enter your details',
                      'input_fields'  => [qw(name email org mailing ensembl_announce ensembl_dev)],
      },
      'preview'      => {
                      'form' => 1,
                      'title' => 'Please check your details',
                      'show_fields'  => [qw(name email org ensembl_announce ensembl_dev)],
                      'pass_fields'  => [qw(name email org ensembl_announce ensembl_dev)],
                      'back' => 1,
      },
      'login'       => {
                      'form' => 1,
                      'input_fields'  => [qw(email password)],
      },
      'add_group'       => { 'form' => 1, title => 'Your new group',
                             'input_fields' => [ qw(group_name) ] },
      'group_settings'       => { 'form' => 1, title => 'Group settings',
                             'input_fields' => [ qw(group_open_check
                                                    group_public_check
                                                    group_private_check
                                                    ) ] },
      'lookup_lost'      => {'button'=>'Send'},
      'lookup_reg'      => {},
      'send_link'       => {},
      'set_cookie'      => {},

      'enter_password' => {
                      'form' => 1,
                      'input_fields'  => [qw(password confirm_password)],
      },
      'save_password' => {'button'=>'Save'},
      'save_details'  => {'button'=>'Save'},
      'save_bookmark' => {'button'=>'Save'},
      'save_config'   => {'button'=>'Save'},
      'save_group'    => {'button'=>'Save'},
      'process_membership' => {'button'=>'Save'},

      'enter_email' => {
                      'form' => 1,
                      'input_fields'  => [qw(email)],
      },
      'thanks_lost'   => {'title' => 'Reactivation Code Sent',
                        'page' => 1,
      },
      'thanks_reg'   => {'title' => 'Activation Code Sent',
                        'page' => 1,
      },
      'accountview'   => {'title' => 'Account Details',
                        'page' => 1,
      },
      'name_bookmark' => {
                      'form' => 1,
                      'title' => 'Save bookmark',
                      'show_fields'  => [qw(bm_url)],
                      'pass_fields'  => [qw(bm_url user_id)],
                      'input_fields'  => [qw(bm_name)],
      },
      'select_bookmarks' => {
                      'form' => 1,
                      'title' => 'Select bookmarks to delete',
                      'input_fields'  => [qw(bookmarks)],
      },
      'delete_bookmarks' => {'button'=>'Delete'},
      'name_config' => {
                      'form' => 1,
                      'title' => 'Save configuration',
                      'show_fields'  => [qw(script)],
                      'pass_fields'  => [qw(script user_id)],
                      'input_fields'  => [qw(config_name)],
      },
      'select_configs' => {
                      'form' => 1,
                      'title' => 'Select configurations to delete',
                      'input_fields'  => [qw(configs)],
      },
      'delete_configs' => {'button'=>'Delete'},
      'show_groups' => {
                      'form' => 1,
                      'title' => 'Select a group to join',
      },
      'groupview'   => {'title' => 'Group Details',
                        'page' => 1,
      },
      'show_members' => {'title' => 'Membership List',
                        'page' => 1,
      },
      'edit_group' => {
                      'form' => 1,
                      'title' => 'Edit Group Details',
                      'access' => {'level'=>'administrator', 'group'=>$webgroup_id},
                      'input_fields'  => [qw(group_name group_blurb group_type)],
                      'pass_fields'  => [qw(webgroup_id)],
      },
);

=pod
=cut
  my $help_email = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;

  my %message = (
    'duplicate' => "Sorry, we appear to have a user with this email address already. Please try again.",
    'password_mismatch' => 'Sorry, the two passwords do not match - please try again.',
    'invalid' => "Sorry, the email address and password did not match a valid account. Please try again.",
    'not_found' => "Sorry, that email address is not in our database. Please try again.",
    'save_failed' => 'Sorry, there was a problem saving your details. Please try again later.',
    'save_ok' => "Thank you for registering with Ensembl! An activation link has been sent to your email address.",
    'update_ok' => "Thank you - your changes have been saved.",
    'send_failed' => qq(Sorry, there was a problem sending your new password. Please contact <a href="mailto:$help_email">$help_email</a> for assistance.),
    'send_ok' => "Your new password has been sent to your registered email address.",
    'no_delete' => 'Sorry, there was a problem deleting your bookmarks. Please try again later.',
    'log_back' => 'Please log back into Ensembl using your new password.',
);

 
  my $data = {
    'expiry'      =>  $expiry,
    'exp_text'    =>  $exp_text,
    'group_types' => \@group_types,
  };

  return [$data, \%form_fields, \%all_nodes, \%message];
}


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

sub add_group {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'add_group';
  my $form = EnsEMBL::Web::Form->new($node, '/' . $species . '/' . $script, 'post');
  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
  return $form;
}

sub group_settings {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'group_settings';
  my $form = EnsEMBL::Web::Form->new($node, '/' . $species . '/' . $script, 'post');
  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
  return $form;
}

sub login {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'login'; 
 
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  my $url = CGI::escape($object->param('url'));

  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $form->add_element(
    'type'  => 'Hidden',
    'name'  => 'url',
    'value' => $url,
  );
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub validate {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check on these details
  my ($is_ok, $not_ok, $result);
  if (my $code = $object->param('code')) {
    $result = $object->get_user_by_code($code);
    $is_ok  = 'enter_password';
    $not_ok = 'enter_email';
    $parameter{'code'} = $code;
  }
  else {
    $result = $object->validate_user($object->param('email'), $object->param('password'));
    $is_ok  = 'back_to_page';
    $not_ok = 'login';
    $parameter{'url'} = $object->param('url');
  }

  ## select response based on results
  if ($result && $$result{'user_id'}) {  ## user OK - proceed with login
    $parameter{'node'} = 'set_cookie';
    $parameter{'next_node'} = $is_ok; 
    $parameter{'user_id'} = $$result{'user_id'}; 
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

  my $url = CGI::escape($object->param('url'));
  $parameter{'set_cookie'}  = $object->param('user_id'); ## sets a cookie, i.e. logs in
  $parameter{'node'}        = $object->param('next_node'); 
  $parameter{'url'}         = $url;

  return \%parameter;
}

sub enter_details {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'enter_details';
 
  my $id = $object->get_user_id;
  my @fields = qw(name email);
  if ($id) { ## updating existing account
    my $details = $object->get_user_by_id($id);
    $object->param('name', $$details{'name'});
    $object->param('email', $$details{'email'});
    $object->param('org', $$details{'org'});
  }
  else { ## new account
    $object->param('next_node', 'preview');
  }
 
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub lookup_lost {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check to see if this user already exists
  my %details = %{$object->get_user_by_email($object->param('email'))};
  my $user_exists = $details{'user_id'} ? 1 : 0;

  if (!$user_exists) {  
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'not_found';
    $parameter{'node'} = 'enter_email'; ## return to input node
  }
  else { ## reset password
    $parameter{'lost'} = 1; 
    $parameter{'node'} = 'save_password'; 
    $parameter{'user_id'} = $details{'user_id'};
    $parameter{'expiry'} = $self->data('expiry'); 
  }

  return \%parameter;
}

sub lookup_reg {
  my ($self, $object) = @_;
  my %parameter; 

  ## do a database check to see if this user already exists
  my %details = %{$object->get_user_by_email($object->param('email'))};
  my $user_exists = $details{'user_id'} ? 1 : 0;

  if ($user_exists) {  
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'duplicate';
    $parameter{'node'} = 'enter_details'; ## duplicate, so return to input node
  }
  else {
    $parameter{'node'} = 'preview'; ## genuine new user, so continue
  }
  my @passable = qw(name email org ensembl_announce ensembl_dev);
  foreach my $p (@passable) {
    $parameter{$p} = $object->param($p);
  }

  return \%parameter;
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

sub save_details {
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

    ## direct to next page
    if ($id) { ## update
      $parameter{'node'} = 'accountview';
      $parameter{'error'} = 0;
      $parameter{'feedback'} = 'update_ok'; 
    }
    else { ## new account
      $parameter{'node'} = 'send_link';
      $parameter{'user_id'} = $result;
      $parameter{'expiry'} = $object->{wizard}->data('expiry'); 
    }
  }
  else {
    $parameter{'node'} = 'enter_details'; 
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
  }

  return \%parameter;
}

sub save_password {
  my ($self, $object) = @_;
  my %parameter; 

  my $id = $object->user_id || $object->param('user_id');
  $object->param('user_id', $id); ## make sure param is set, or we can't save record!

  ## set password
  my $record = $self->create_record($object);
  my $code = $object->set_password($record);

  if ($code) {
    if ($object->param('expiry')) { ## password has been auto-set
      $parameter{'node'} = 'send_link'; 
      $parameter{'code'} = $code; 
      $parameter{'user_id'} = $id; 
      $parameter{'lost'} = $object->param('lost'); 
    }
    else {
      $parameter{'node'}  = 'accountview'; 
    }
  }
  else {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'save_failed';
    ## N.B. If node is left blank, will go to default for the originating wizard
  }

  return \%parameter;
}

sub send_link {
  ## Sends email with account (re)activation link.
  my ($self, $object) = @_;
  my %parameter; 

  ## send password link to user
  my $id = $object->user_id || $object->param('user_id');
  my %details =  %{ $object->get_user_by_id($id) }; 
  my $email = $details{'email'};
  my $name  = $details{'name'};

  if ($email) {

    my $exp_text = $self->data('exp_text');
    my $help_email  = $object->species_defs->ENSEMBL_HELPDESK_EMAIL;
    my $base_url    = $object->species_defs->ENSEMBL_BASE_URL;
    my $website     = $object->species_defs->ENSEMBL_SITETYPE;
    my $link = "$base_url/common/set_password?node=validate;code=".$object->param('code');

    my $message = "Dear $name\n\n";
    my $subject;
    if ($object->param('lost')) {

      $parameter{'node'} = 'thanks_lost'; 
      $subject = "$website - Lost Password";
      $message .= qq(We have received a lost password request from your $website account. Please use the link below to reset your password:

$link

);
    }
    else {

      $parameter{'node'} = 'thanks_reg'; 
      $subject = "Welcome to $website";
      $message .= qq(Thank you for registering with $website. To activate your account, please use the link below; you will be asked to set a password so that you can log in.

$link;activate=1

);
    }
    $message .= qq(Please note that the code expires after $exp_text. If you have any problems, you can reply to this email to contact the $website Helpdesk.


Regards

$website Helpdesk
    );

    $self->_mail($email, $help_email, $help_email, $subject, $message);
  }

  return \%parameter;
}

sub thanks_lost {} ## stub - doesn't do anything wizardy!
sub thanks_reg  {} ## stub - doesn't do anything wizardy!

sub enter_password {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
 
  my $node = 'enter_password';
  my $form = EnsEMBL::Web::Form->new( $node, "/$species/$script", 'post' );

  if ($object->param('activate')) {
    $wizard->field('password', 'label', 'Password'); 
  }
  else {
    $form->add_element(
      'type'  => 'Information',
      'value' => 'Please choose a new password for your account',
    ); 
  }

  $wizard->add_widgets($node, $form, $object);
  if (my $code = $object->param('code')) {
    $form->add_element('type'=>'Hidden', 'name'=>'code', 'value'=>$code);
  }
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub compare {
  ## Compare two passwords to ensure user has typed correctly
  my ($self, $object) = @_;
  my %parameter; 
  
  my $pass1 = $object->param('password');
  my $pass2 = $object->param('confirm_password');
  $parameter{'user_id'}  = $object->user_id;
  if ($pass1 eq $pass2) {
    $parameter{'node'} = 'save_password';
    $parameter{'password'} = $pass1;
  }
  else {
    $parameter{'node'} = 'enter_password';
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'password_mismatch';
  }

  return \%parameter;
}

sub enter_email {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  
  my $form = EnsEMBL::Web::Form->new( 'enter_email', "/$species/$script", 'post' );

  $wizard->add_widgets('enter_email', $form, $object);
  $wizard->add_buttons('enter_email', $form, $object);

  return $form;
} 


sub logout {
  my ($self, $object) = @_;
  my %parameter; 

  my $url = CGI::escape($object->param('url'));

  $parameter{'set_cookie'}  = 0; ## sets a blank cookie, i.e. logs out
  $parameter{'exit'}  = $url; 

  return \%parameter;
}

sub back_to_page {
  my ($self, $object) = @_;
  my %parameter;

  my $url = CGI::escape($object->param('url'));
  $parameter{'exit'}  = $url; 
  return \%parameter;
}


########################### USER CUSTOMISATION METHODS #######################################

#--------------------------------- BOOKMARKS -------------------------------------------------

sub name_bookmark {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'name_bookmark';
  
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

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

  ## save bookmark
  #my $record = $self->create_record($object);
  #$$record{'user_id'} = $object->user_id;
  #my $result = $object->save_bookmark($record);
  my $result = 0;
  if ($ENV{'ENSEMBL_USER_ID'}) {
    my $bookmark = EnsEMBL::Web::User::Record->new(( 
                                                     type => 'bookmark',
                                                     user => $ENV{'ENSEMBL_USER_ID'}
                                                  )); 
    $bookmark->url($object->param('bm_url'));
    $bookmark->name($object->param('bm_name'));
    $result = $bookmark->save;
  }

  ## set response
  if ($result) {
    $parameter{'node'} = 'back_to_page';
    $parameter{'url'} = CGI::escape($object->param('bm_url'));
  }
  else {
    $parameter{'node'} = 'accountview';
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'no_bookmark';
  }
  return \%parameter;
}

sub select_bookmarks {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'select_bookmarks';

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_title($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

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

#------------------------------ USER CONFIGS -------------------------------------------------

sub name_config {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'name_config';
  
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  ## parse URL for name of originating script
  my $url = $object->param('url');
  $url =~ m#/([a-zA-z]+view)#;
  my $config_script = $1;
  $object->param('script', $config_script); 
  $object->param('config_name', $config_script); 
  $object->param('user_id', $object->user_id); 

  $wizard->add_title($node, $form, $object);
  $wizard->show_fields($node, $form, $object);
  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $form->add_element(
    'type'  => 'Hidden',
    'name'  => 'url',
    'value' => $object->param('url'),
  );
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub save_config {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard}; 
 
  my %parameter;

  ## save config
  my $record = $self->create_record($object);
  $$record{'session_id'} = $ENV{'ENSEMBL_FIRSTSESSION'};
  my $result = $object->save_config($record);

  ## set response
  if ($result) {
    $parameter{'node'} = 'back_to_page';
    $parameter{'url'} = CGI::escape($object->param('url'));
  }
  else {
    $parameter{'node'} = 'accountview';
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'no_config';
  }
  return \%parameter;
}

sub select_configs {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'select_configs';

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->simple_form($node, $form, $object, 'input');

  return $form;
}

sub delete_configs {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};

  my %parameter;
  $parameter{'node'} = 'accountview';

  ## get list of configs to delete
  my @deletes;
  if (ref($object->param('configs')) eq 'ARRAY') {
    @deletes = @{ $object->param('configs') };
  }
  else {
    push @deletes, $object->param('configs');
  }
  my $result = $object->delete_configs(\@deletes);
  unless ($result) {
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'no_delete';
  }
  return \%parameter;
}

#------------------------------ USER CONFIGS -------------------------------------------------

sub process_membership {
  my ($self, $user) = @_;
  my $wizard = $self->{wizard}; 
 
  warn "PROCESS MEMBERSHIP: " . $user->name;
  warn "PARAM: " . $user->param;
  #foreach my $key (keys $user->param) {
  #  warn "PROCESS KEY: " . $key;
  #}
  my %parameter;
  $parameter{'node'} = 'accountview'; 
  return \%parameter;
}

sub show_groups {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'show_groups';

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  my $groups = $object->find_groups_by_type('open');

  if (@{ $groups }) {
    $form->add_element(
        'name'  => 'open_subhead',
        'type'  => 'SubHeader',
        'value' => 'Open Groups',
    );
    $form->add_element(
        'name'  => 'open_blurb',
        'type'  => 'Information',
        'value' => "Open groups can be joined by anyone. If you select any of these groups, you will get instant access to any custom configurations created by the group's administrator.",
    );
    $wizard->add_list_of_groups($groups, $form);
  }
  
  my $restricted_groups = $object->find_groups_by_type('restricted');
  if (@{ $restricted_groups }) {
    $form->add_element(
      'name'  => 'restricted_subhead',
      'type'  => 'SubHeader',
      'value' => 'Restricted Groups',
    );
    $form->add_element(
      'name'  => 'restricted_blurb',
      'type'  => 'Information',
      'value' => "Before you can join a restricted group, you have to be approved by the group's moderator. You can request to join such a group here, and you will receive a reply by email.",
    );

    $wizard->add_list_of_groups($restricted_groups, $form);
  } 

  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub add_list_of_groups {
  my ($self, $groups, $form) = @_;
  foreach my $group (@{ $groups }) {
    $form->add_element(
      'type'  => 'CheckBox',
      'label' => $group->name,
      'name'  => 'group',
      'value' => $group->id,
      'notes' => $group->blurb,
    );
    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'group_'.$group->id,
      'value' => 'open',
    );
  }
}

sub save_membership {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard};
  my (%parameter, %record, %result);

  my @groups = $object->param('groups');
  $record{'user_id'} = $object->user_id;
  $record{'logged_in'} = $object->user_id;
  foreach my $group (@groups) {
    $record{'group_id'} = $group;
    my $type = $object->param('group_'.$group);
    if ($type eq 'open') {
      $record{'status'} = 'active';
    }
    elsif ($type eq 'restricted') {
      $record{'status'} = 'pending';
      $object->notify_admin(\%record);
    }
    else {
      next;
    }
    $result{$group} = $object->save_membership(\%record);
  }

  ## set response
  if (keys %result) {
    $parameter{'node'} = 'accountview';
    $parameter{'error'} = 0;
  }
  else {
    $parameter{'error'} = 1;
  }
  return \%parameter;
}

sub groupview { 
  ## doesn't do anything wizardy, just displays some info and links
  return 1;
}

sub edit_group {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'edit_group';

  if (!$object->param('webgroup_id')) {
    $wizard->redefine_node($node, 'title', 'Enter Group Details');
  }

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub enter_group {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'enter_group';

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub save_group {
  my ($self, $user) = @_;
  my $wizard = $self->{wizard}; 
 
  my %parameter;

  ## save config
  ## create_record returns an array with:
  ## group_name
  ## user_id
  ## group_blurb

  my $record = $self->create_record($user);
  $record->{'user_id'} = $user->user_id;
  my $group = EnsEMBL::Web::Object::Group->new((
                                        name => $record->{'group_name'}, 
                                        description => $record->{'group_blurb'}, 
                                        type => 'open',
                                        status => 'active',
                                        adaptor => $user->adaptor
                                      ));
  $user->add_group($group);
  $user->save;

  my $result = 1;
  ## set response
  if ($result) {
    $parameter{'node'} = 'groupview';
    $parameter{'webgroup_id'} = $group->id;
  }
  else {
    $parameter{'node'} = 'accountview';
    $parameter{'error'} = 1;
    $parameter{'feedback'} = 'no_groupsave';
  }

  return \%parameter;
}

sub admin_groups {
### Displays a list of the groups that an administrator is in charge of
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'admin_groups';
=pod
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
=cut
}

sub show_members {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'show_members';
=pod
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post' );

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
=cut
}

sub activate_member {
  my ($self, $object) = @_;
  my $wizard = $self->{wizard}; 
 
  my %parameter;

  ## save config
  my $record = $self->create_record($object);
  my $result = 1; #$object->save_membership($record);

  ## set response
  $parameter{'node'} = 'show_members';
  if (!$result) {
    $parameter{'error'} = 1;
  }
  return \%parameter;
}

1;

                                                                                
