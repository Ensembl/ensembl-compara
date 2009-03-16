package EnsEMBL::Web::Component::Account::ManageGroup;

### Module to create list of groups that a user is an admin of

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;
#use EnsEMBL::Web::Data::Membership;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;

  ## Control panel fixes
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  return '' unless $object->param('id') && int($object->param('id'));
 
  my $ok_id = $user->is_administrator_of($object->param('id')) ? $object->param('id') : undef;
  if ($ok_id) {
    my $group = EnsEMBL::Web::Data::Group->new($ok_id);
    $html .= '<h2>'.$group->name.'</h2>';

    ## Error messages from invitation module
    if ($object->param('active') || $object->param('pending')) {
      my $caption = 'Invitations';
      my $text;
      my @active = $object->param('active');
      foreach my $email (@active) {
        next unless $email;
        $text .= qq(<p>$email is already a member of this group.</p>);
      }
      my @pending = $object->param('pending');
      foreach my $email (@pending) {
        next unless $email;
        $text .= qq(<p>$email has already been invited to join this group.</p>);
      }
      $html .= $self->_error($caption, $text, '100%');
    }

    ## List of current members
    $html .= qq(<h3 style="margin-bottom:0px">Current members</h3>);

    my @members = $group->members;

    if (@members) {

      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0.5em 0px'} );
      $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '25%', 'align' => 'left' },
        { 'key' => 'status',    'title' => 'Status',        'width' => '25%', 'align' => 'left' },
        { 'key' => 'remove',    'title' => '',              'width' => '25%', 'align' => 'left' },
        { 'key' => 'promote',   'title' => '',              'width' => '25%', 'align' => 'left' },
      );
 
      my $show_all = $object->param('show_all') ? 1 : 0; 
      my $inactive = 0;
      foreach my $m (@members) {
        my $row = {};
        $inactive++ if $m->member_status eq 'inactive';
        next unless ($show_all || $m->member_status eq 'active');
        my $status = ucfirst($m->level);
        if ($show_all) {
          $status .= ' ('.$m->member_status.')';
        }
        my ($remove, $promote);
        if ($m->id == $user->id) {
          $remove = qq(<a href="/Account/Unsubscribe?id=$ok_id;$referer" class="modal_link">Unsubscribe</a> (N.B. You will no longer have any access to this group!));
        }
        else {
          if ($m->member_status eq 'inactive') {
            $remove = sprintf(qq(<a href="/Account/RemoveMember?id=$ok_id;user_id=%s;$referer" class="modal_link">Remove from group</a>), $m->user_id);
          }
          else { 
            $remove = sprintf(qq(<a href="/Account/ChangeStatus?id=$ok_id;new_status=inactive;user_id=%s;$referer" class="modal_link">Deactivate membership</a>), $m->user_id);
          }
        }
        if ($status eq 'Administrator') {
          $promote = sprintf(qq(<a href="/Account/ChangeLevel?id=$ok_id;new_level=member;user_id=%s;$referer" class="modal_link">Demote to standard member</a>), $m->user_id);
        }
        else {
          $promote = sprintf(qq(<a href="/Account/ChangeLevel?id=$ok_id;new_level=administrator;user_id=%s;$referer" class="modal_link">Promote to administrator</a>), $m->user_id);
        }
        $table->add_row({'name' => $m->name, 'status' => $status, 'remove' => $remove, 'promote' => $promote});
        #$table->add_row({'name' => 'name', 'status' => $status, 'remove' => $remove, 'promote' => $promote});
      }
      $html .= $table->render;
      if ($show_all) {
        $html .= qq(<p><a href="/Account/ManageGroup?id=$ok_id;$referer" class="modal_link">Hide non-active members</a> (if any)</p>);
      }
      elsif ($inactive) {
        $html .= qq(<p><a href="/Account/ManageGroup?id=$ok_id;show_all=yes;$referer" class="modal_link">Show $inactive non-active members</a></p>);
      }
    }
    else {
      $html .= "<p>This group has no members</p>"; ## Unlikely, since it must have a creator!
    }

    ## Pending invitations
    $html .= qq(<h3 style="margin-bottom:0px">Pending invitations</h3>);
    my @invites = $group->invites;

    if (@invites) {

      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0.5em 0px'} );
      $table->add_columns(
        { 'key' => 'email',    'title' => 'Email',        'width' => '50%', 'align' => 'left' },
        { 'key' => 'remove',   'title' => '',             'width' => '50%', 'align' => 'left' },
      );

      foreach my $invitation (@invites) {
        $table->add_row({'email' => $invitation->email, 
          'remove' => qq(<a href="/Account/RemoveInvitation?id=).$invitation->id.';group_id='.$group->id.qq(;$referer" class="modal_link">Cancel invitation</a>)});
      }
      $html .= $table->render;
    }
    else {
      $html .= "<p>This group has no invitations pending acceptance.</p>";
    }

    ## Invitation form
    $html .= qq(<h3>Invite new members</h3>
<p>To invite new members into this group, enter one email address per person. Users not already registered with this website will be asked to do so before accepting your invitation.</p>);

    my $form = EnsEMBL::Web::Form->new('invitations', "/Account/Invite", 'post', 'std check narrow-labels');

    $form->add_element(type => 'Text', name=>'emails', label => 'Email addresses', 
                      'notes' => 'Multiple email addresses should be separated by commas');

    $form->add_element(type => 'Hidden', name => 'id', value => $group->id);
    $form->add_element(type => 'Hidden', name => '_referer', value => $object->param('_referer'));
    $form->add_element(type => 'Hidden', name => 'x_requested_with', value => $object->param('x_requested_with'));

    $form->add_element(type => 'Submit', name => 'submit', value => 'Send');

    $html .= $form->render;
  }

  return $html;
}

1;
