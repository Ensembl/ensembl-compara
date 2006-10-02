package EnsEMBL::Web::Wizard::User;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
use Mail::Mailer;
use CGI;

our @ISA = qw(EnsEMBL::Web::Wizard);



sub _init {
  my ($self, $object) = @_;

  
  my $expiry =  86400 * 3; ## expiry period for temporary server-set passwords, in seconds
  my $exp_text = '3 days'; ## expiry period in words (used in emails, etc.)

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
      'validate'      => {'button'=>'Login'},
      'lookup_lost'      => {'button'=>'Send'},
      'lookup_reg'      => {},
      'send_link'       => {},
      'set_cookie'      => {},

      'enter_password' => {
                      'form' => 1,
                      'input_fields'  => [qw(password confirm_password)],
      },
      'save_password'=> {'button'=>'Save'},
      'save_details' => {'button'=>'Save'},

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
      'save_bookmark' => {'button'=>'Save'},
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
      'save_config' => {'button'=>'Save'},
      'select_configs' => {
                      'form' => 1,
                      'title' => 'Select configurations to delete',
                      'input_fields'  => [qw(configs)],
      },
      'delete_configs' => {'button'=>'Delete'},
);

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

  ## get useful data from object
  my $user_id = $object->get_user_id;
  my @bookmarks = @{ $object->get_bookmarks($user_id) };
  my (@bm_values, @config_values);
  foreach my $bookmark (@bookmarks) {
    my $bm_id   = $$bookmark{'bm_id'};
    my $bm_name = $$bookmark{'bm_name'};
    my $bm_url  = $$bookmark{'bm_url'};
    push @bm_values, {'value'=>$bm_id,'name'=>"$bm_name ($bm_url)"};
  }
  my @configs = @{ $object->get_configs($user_id) };
  my @bm_values;
  foreach my $config (@configs) {
    my $config_id   = $$config{'config_id'};
    my $config_name = $$config{'config_name'};
    my $script      = $$config{'script'};
    push @config_values, {'value'=>$config_id,'name'=>"$config_name ($script)"};
  }
  my $details   = $object->get_user_by_id($user_id);

  my $data = {
    'expiry'      =>  $expiry,
    'exp_text'    =>  $exp_text,
    'details'     => $details,
    'bookmarks'   => \@bm_values,
    'configs'     => \@config_values,
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
  my $record = $self->create_record($object);
  $$record{'user_id'} = $object->user_id;
  my $result = $object->save_bookmark($record);

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

1;

                                                                                
