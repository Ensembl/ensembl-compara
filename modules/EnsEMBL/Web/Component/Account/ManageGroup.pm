# $Id$

package EnsEMBL::Web::Component::Account::ManageGroup;

### Module to create list of groups that a user is an admin of

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Component::Account);

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

  my $user = $object->user;
  my $sitename = $self->site_name;

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

      my $table = $self->new_table([], [], { margin => '0.5em 0px' });
      $table->add_columns(
        { 'key' => 'name',    'title' => 'Name',   'width' => '25%', 'align' => 'left' },
        { 'key' => 'status',  'title' => 'Status', 'width' => '25%', 'align' => 'left' },
        { 'key' => 'remove',  'title' => '',       'width' => '25%', 'align' => 'left' },
        { 'key' => 'promote', 'title' => '',       'width' => '25%', 'align' => 'left' },
      );
 
      my $show_all = $object->param('show_all') ? 1 : 0; 
      my $inactive = 0;
      foreach my $m (sort {$a->name cmp $b->name} @members) {
        my $row = {};
        $inactive++ if $m->member_status eq 'inactive';
        next unless ($show_all || $m->member_status eq 'active');
        my $status = ucfirst($m->level);
        if ($show_all) {
          $status .= ' ('.$m->member_status.')';
        }
        my ($remove, $promote);
        if ($m->user_id == $user->id) {
          $remove = qq(<a href="/Account/Unsubscribe?id=$ok_id" class="modal_link">Unsubscribe</a> (N.B. You will no longer have any access to this group!));
        }
        else {
          if ($m->member_status eq 'inactive') {
            $remove = sprintf(qq(<a href="/Account/RemoveMember?id=$ok_id;user_id=%s" class="modal_link">Remove from group</a>), $m->user_id);
          }
          else { 
            $remove = sprintf(qq(<a href="/Account/ChangeStatus?id=$ok_id;new_status=inactive;user_id=%s" class="modal_link">Deactivate membership</a>), $m->user_id);
          }
        }
        if ($status eq 'Administrator') {
          $promote = sprintf(qq(<a href="/Account/ChangeLevel?id=$ok_id;new_level=member;user_id=%s" class="modal_link">Demote to standard member</a>), $m->user_id);
        }
        elsif ($m->member_status ne 'active') {
          $promote = sprintf(qq(<a href="/Account/ChangeLevel?id=$ok_id;new_level=administrator;user_id=%s" class="modal_link">Promote to administrator</a>), $m->user_id);
        }
        $table->add_row({'name' => $m->name, 'status' => $status, 'remove' => $remove, 'promote' => $promote});
        #$table->add_row({'name' => 'name', 'status' => $status, 'remove' => $remove, 'promote' => $promote});
      }
      $html .= $table->render;
      if ($show_all) {
        $html .= qq(<p><a href="/Account/ManageGroup?id=$ok_id" class="modal_link">Hide non-active members</a> (if any)</p>);
      }
      elsif ($inactive) {
        $html .= qq(<p><a href="/Account/ManageGroup?id=$ok_id;show_all=yes" class="modal_link">Show $inactive non-active members</a></p>);
      }
    }
    else {
      $html .= "<p>This group has no members</p>"; ## Unlikely, since it must have a creator!
    }

    ## Pending invitations
    $html .= qq(<h3 style="margin-bottom:0px">Pending invitations</h3>);
    my @invites = $group->invites;

    if (@invites) {

      my $table = $self->new_table([], [], { margin => '0.5em 0px' });
      $table->add_columns(
        { 'key' => 'email',    'title' => 'Email',        'width' => '50%', 'align' => 'left' },
        { 'key' => 'remove',   'title' => '',             'width' => '50%', 'align' => 'left' },
      );

      foreach my $invitation (@invites) {
        $table->add_row({'email' => $invitation->email, 
          'remove' => qq(<a href="/Account/RemoveInvitation?id=).$invitation->id.';group_id='.$group->id.qq(" class="modal_link">Cancel invitation</a>)});
      }
      $html .= $table->render;
    }
    else {
      $html .= "<p>This group has no invitations pending acceptance.</p>";
    }

    ## Invitation form
    $html .= qq(<h3>Invite new members</h3>
<p>To invite new members into this group, enter one email address per person. Users not already registered with this website will be asked to do so before accepting your invitation.</p>);

    my $form = $self->new_form({
      'id'      => 'invitations',
      'action'  => '/Account/Invite',
      'class'   => 'std narrow-labels'});

    my $fieldset = $form->add_fieldset;

    $fieldset->add_hidden({'type' => 'Hidden', 'name' => 'id', 'value' => $group->id});
    
    $fieldset->add_field([
      {'type' => 'Text',   'name' => 'emails', 'label' => 'Email addresses', 'notes' => 'Multiple email addresses should be separated by commas'},
      {'type' => 'Submit', 'name' => 'submit', 'value' => 'Send'}
    ]);

    $html .= $form->render;
  }

  return $html;
}

1;
