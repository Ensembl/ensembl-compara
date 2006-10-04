package EnsEMBL::Web::Component::DASCollection;
=head1 NAME

EnsEMBL::Web::Component::DASCollection;

=head1 SYNOPSIS

Web Component used to render dasconfview pages

=head1 DESCRIPTION

Web Component used to render dasconfview pages

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut
use EnsEMBL::Web::Component;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities;

my $btnNext = 'Next';
my $btnBack = 'Back';
my $btnFinish = 'Finish';


my %DASWizard = (
  'das_url' => { 
    TEXT => 'URL based source', 
    FUNC => \&add_das_url,
    HELP => 'data located in a file on a web server'},
  'das_file' => { 
    TEXT => 'Data upload', 
    FUNC => \&add_das_file, 
    HELP => 'Upload your own annotation to ensembl server',
    ENSEMBL_HELP => "javascript:void(window.open('/perl/helpview?se=1&kw=dasconfview#Upload','dasconfview','width=400,height=500,resizable,scrollbars'));"
  },
  'das_server' => {
    TEXT => 'Annotation server', 
    FUNC => \&add_das_server,
    HELP => 'data provided by DAS server',
    ENSEMBL_HELP => "javascript:void(window.open('/perl/helpview?se=1&kw=dasconfview#DSN','dasconfview','width=400,height=500,resizable,scrollbars'));"
  },
);

my $_select_tmpl = qq(
<select %s> %s
</select> );

my $_option_tmpl = qq(
 <option value="%s" %s> %s </option> );

sub _formelement_select {
    my $input = shift;
    my $name    = shift || die( "Need a formelement name" );
    my $options = shift || die( "Need some option values" );
    my $labels  = shift || {};
    my $attribs = shift || {};
    my $default = shift || '';
    ref( $options ) eq 'ARRAY' || die( "Option values must be an arrayref" );
    ref( $labels  ) eq 'HASH'  || die( "Option labels must be a hashref" );
    my $old_value = ($name =~ /\:(.+)/ ? $input->param($1) : $input->param($name));
    $old_value ||= $default;
    $attribs->{name} = $name;
    my @attribs = map{ sprintf('%s="%s"', $_, $attribs->{$_}) } keys %$attribs;
    my $attrib_str = join( ' ', @attribs );
    my $option_str = '';
    foreach my $opt( @$options ){
    my $selected = $opt eq $old_value ? 'selected' : '';
    my $label    = $labels->{$opt} || $opt;
    $option_str .= sprintf( $_option_tmpl, $opt, $selected, $label );
    }
    return sprintf( $_select_tmpl, $attrib_str, $option_str );
}

sub get_das_domains {
    my ($object) = @_;
    my @domains = ();    
    
    push( @domains, @{$object->species_defs->ENSEMBL_DAS_SERVERS || []});
    push( @domains, map{$_->adaptor->domain} @{$object->Obj} );
    push( @domains, $object->param("DASdomain")) if ($object->param("DASdomain") ne $object->species_defs->DAS_REGISTRY_URL);

    my @urls;
    foreach my $url (sort @domains) {
	$url = "http://$url" if ($url !~ m!^\w+://!);
	$url .= "/das" if ($url !~ m!/das$!);
	push @urls, $url;
    }
    my %known_domains = map { $_ => 1} grep{$_} @urls ;
    return  sort keys %known_domains;
}

sub get_server_dsns {
    my ($object) = @_;
    if (my $url = $object->param('DASdomain')) {
	my $filterT = sub {
	    return 1;
	};
	my $filterM = sub {
	    return 1;
	};

	my $keyText = $object->param('keyText');
	my $keyMapping = $object->param('keyMapping');
	
	if (defined (my $dd = $object->param('_das_filter'))) {
	    if ($keyText) {
		$filterT = sub { 
		    my $src = shift; 
		    return 1 if ($src->{url} =~ /$keyText/); 
		    return 1 if ($src->{name} =~ /$keyText/); 
		    return 1 if ($src->{description} =~ /$keyText/); 
		    return 0; };
	    }
	
	    if ($keyMapping ne 'any') {
		$filterM = sub { 
		    my $src = shift; 
		    foreach my $cs (@{$src->{mapping_type}}) {
			return 1 if ($cs eq $keyMapping);
		    }
		    return 0; 
		};
	    }
	}



        use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
        my $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new
	    ( 
	      -url  => $url,
	      -timeout   => 5,
	      -proxy_url => $object->species_defs->ENSEMBL_WWW_PROXY 
	      );

        use Bio::EnsEMBL::ExternalData::DAS::DAS;
        my $das = Bio::EnsEMBL::ExternalData::DAS::DAS->new ( $adaptor );
        my %dsnhash = map {$_->{id}, $_} grep {$filterT->($_)} @{ $das->fetch_dsn_info };
        if( %dsnhash ){
            return \%dsnhash;
        } else{
            $object->param('_error_das_domain', 'No DSNs for domain');
        }
    } else{
	$object->param('_error_das_domain',   'Need a domain');
    }
    return;
}

sub add_das_server {
    my ($form, $source_conf, $object, $step_ref) = @_;

    $form->add_element( 'type'     => 'Information', 'value'    => 'Please select DAS sources to attach and click <b>Next</b>:' );

    &wizardTopPanel($form, $$step_ref, $source_conf->{sourcetype});
    

    if (defined($object->param('_das_add_domain.x'))) {
	my $btnList = qq{  <input type="image" name="_das_list_dsn" src="/img/buttons/dsnlist_small.gif" class="form-button" /> };

	$form->add_element('type' => 'String',
			   'name'     => 'DASdomain',
			   'label'    => 'DAS Server URL: ( e.g. http://www.example.com/MyProject/das )',
			   'notes' => $btnList
			   );


    } else {
	my $NO_REG = 'No registry';
	my $rurl = $object->species_defs->DAS_REGISTRY_URL || $NO_REG;


	if (defined (my $url = $object->param("DASdomain"))) {
	    $url = "http://$url" if ($url !~ m!^\w+://!);
	    $url .= '/das' if ($url !~ m!/das$! && $url ne $rurl);
	    $object->param('DASdomain', $url);
	}
	my @das_servers = &get_das_domains($object);

#	warn("SERVERS:".Dumper(\@das_servers));
	my @dvals = ();
	if ($rurl eq $NO_REG) {
	    $object->param("DASdomain") or $object->param("DASdomain", $das_servers[0]);
	} else {
	    $object->param("DASdomain") or $object->param("DASdomain", $rurl);
	    push @dvals, {'name' => 'DAS Registry', 'value'=>$rurl};
	}

	my $default = $object->param("DASdomain");

#	warn("DEFAULT: $default");

	foreach my $dom (@das_servers) { push @dvals, {'name'=>$dom, 'value'=>$dom} ; }


	my $btnMore = qq{  <input type="image" name="_das_add_domain" src="/img/buttons/more_small.gif" class="form-button" /> };


	$form->add_element('type'     => 'DropDown',
			   'select'   => 'select',
			   'name'     => 'DASdomain',
			   'label'    => 'DAS Server URL:',
			   'values'   => \@dvals,
			   'value'    => $default, 
			   'notes' => $btnMore,
			   'on_change' => 'submit',
			   );
    
	$form->add_element(
			   'type'     => 'String',
			   'name'     => 'DASuser_source',
			   'label'    => "DAS source name (only for Ensembl user-uploaded sources, e.g. hydraeuf_00000001 or hydrasource_00000010)",
			   'value'    => $source_conf->{userdsn}
                       );


	if ($object->param("DASdomain") =~ m!^$rurl!) {
	    &add_das_registry($form, $source_conf, $object);
	} else {
	    wizard_search_box ($form, $source_conf, $object, 0);

	    my $dsns = &get_server_dsns($object);

	    my %selected_sources = ();
	    if (defined($source_conf->{dsns_selection})) {
		foreach (@{$source_conf->{dsns_selection}}) {
		    $selected_sources{$_} = 1;
		}
	    }

	    my $dwidth = 120;
	    
	    my $html = qq{<table>};

	    foreach my $id (sort {$dsns->{$a}->{name} cmp $dsns->{$b}->{name} } keys (%{$dsns})) {
		my $dassource = $dsns->{$id};
		my ($id, $name, $url, $desc) = ($dassource->{id}, $dassource->{name}, $dassource->{url}, substr($dassource->{description}, 0, $dwidth));
		my $cs = qq{<a href="javascript:X=window.open(\'$url\', \'DAS source details\', \'left=50,top=50,resizable,scrollbars=yes\');X.focus();void(0);">details about \`$name\`</a>};
		my $selected = $selected_sources{$id} ? 'checked' : '';
    
		if( length($desc) == $dwidth ) {
# find the last space character in the line and replace the tail with ...        
		    $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./;
		}
		$html .= qq{\n  <tr><td><input type="checkbox" name="DASdsns" value="$id" $selected ></td><td>$name</td><td><b>$url</b><br>$desc<br>$cs</td></tr>};
	    }

	    $html .= qq{\n</table>\n};
	    $form->add_element( 'type'=>'Information', 'value'=> $html );
	}
    }




    return;
}

sub das_wizard_1 {
    my ($form, $source_conf, $object, $step_ref, $error) = @_;
    my $das_type = $source_conf->{sourcetype};
    return $DASWizard{$das_type}->{FUNC}($form, $source_conf, $object, $step_ref, $error);
}

sub das_wizard {
    my( $panel, $object ) = @_;

    my $html = '';
    foreach my $p ($object->param()) {
        $html .= "$p => ".join('*', $object->param($p))."<br />";
    }

    return if (defined($object->param('_das_submit')));

    my %source_conf = ();        
    my $step;

    my @confkeys = qw(fg_grades fg_data fg_max fg_min fg_merge stylesheet score strand label dsn caption type depth domain group name protocol labelflag color help url linktext linkurl);

    if (defined(my $new_das = $object->param('_das_add'))) {
        $step = 1;
        $source_conf{sourcetype} = $new_das;
        $object->param('DASsourcetype', $new_das);
    } elsif (defined(my $src = $object->param('_das_edit'))) {
# Editing a source. 
# All parameters are set in &display_wizaard_status of Configuration/DASCollection.pm
# Hence here we just go straight to the last stage of the wizard
        $step = 3;
	$source_conf{sourcetype} = 'das_server';
    }
    if (! defined($step)) {
        $step = $object->param('DASWizardStep');
    }
    return unless (defined ($step));
    if (defined(my $sd = $object->param('_das_Step'))) {
    if ($sd eq $btnNext) {
        $step ++;
    } elsif ($sd eq $btnBack) {
        $step --;
    }
    }

    foreach my $key (@confkeys) {
        my $hkey = "DAS$key";
        $source_conf{$key} = $object->param($hkey);
    }

    $source_conf{sourcetype} ||= $object->param("DASsourcetype");
    $source_conf{group} ||= 'n';
    $source_conf{user_source} ||= $object->param("DASuser_source");
    @{$source_conf{enable}} = $object->param("DASenable");

    @{$source_conf{registry_selection}} = $object->param("DASregistry") ? $object->param("DASregistry") : ();

    @{$source_conf{dsns_selection}} = $object->param("DASdsns") ? $object->param("DASdsns") : ();

    if (my $scount = scalar(@{$source_conf{registry_selection}})) {
	my $dreg = $object->getRegistrySources();
	my %das_list = ();
	my ($prot, $url, $dsn, $dname);
	foreach my $src (@{$source_conf{registry_selection}}) {
	    my $dassource = $dreg->{$src};
	    $dname = $dassource->{nickname};
	    if ($dassource->{url} =~ /(https?:\/\/)(.+das)\/(.+)/) {
		($prot, $url, $dsn) = ($1, $2, $3);
		$dsn =~ s/\///;
		$das_list{$url}->{$dsn} = $dname;
	    }
	}


	$source_conf{shash} = \%das_list;
	$source_conf{scount} = $scount;
	if ($scount > 1) {
	    $source_conf{name} = 'As nickname in registry';
	    $source_conf{label} = 'As nickname in registry';
	} else {
	    $source_conf{name} ||= $dname;
	    $source_conf{label} ||= $dname;
	}
    }

    if (my $scount = scalar(@{$source_conf{dsns_selection}})) {
	my %das_list = ();
	my $dname;
	foreach my $src (@{$source_conf{dsns_selection}}) {
	    my $url = $object->param("DASdomain");
	    $dname = $src;
	    $das_list{$url}->{$dname} = $src;
	}


	$source_conf{shash} = \%das_list;
	$source_conf{scount} = $scount;
	if ($scount > 1) {
	    $source_conf{name} = 'As DSN';
	    $source_conf{label} = 'As DSN';
	} else {
	    $source_conf{name} ||= $dname;
	    $source_conf{label} ||= $dname;
	}
    }

    @{$source_conf{mapping}} = $object->param("DAStype");

# If there are more than 1 mapping selected set the source type to mixed 
    if (scalar(@{$source_conf{mapping}}) > 1) {
	$source_conf{type} = 'mixed';
    }
    my $form;
    my $onSubmit;

    if ($source_conf{sourcetype} eq 'das_file')  { 
      $form = EnsEMBL::Web::Form->new( 'das_wizard', "/$ENV{ENSEMBL_SPECIES}/dasconfview", 'post');
      $form->add_attribute('ENCTYPE', 'multipart/form-data');
      $onSubmit = qq{
	  var rc = true;
	  var s = document.das_wizard.DASWizardStep.value;
	  var f = document.das_wizard;
	  var warning = '';
	  if (s == 1) {
	      var e = f.DASuser_email.value;
	      var ff = /^[\\w\\.]+@\\w+\\.[\\w\\.]+/.test(e);
	      if (ff == 0) {
		  warning = 'You need to provide a valid email.';
		  rc = false;
	      }
	      var p = f.DASuser_password.value;
	      var fa = /^.+/.test(p);
	      if (fa == 0) {
		  warning = warning + 'You need to provide a password.';
		  rc = false;
	      }
	      var d = f.DASpaste_data.value;
	      var fb = /^.+/.test(d);
	      if (fb == 0) {
		  var f = f.DASfilename.value;
		  var fe = /^.+/.test(f);
		  if (fe == 0) {
		      warning = warning + 'You need to select data to upload.';
		      rc = false;
		  }
	      }

	  }

	  if (rc == false) {
	      alert(warning);
	  }
	  return rc;
      };

    } else {
	$form = EnsEMBL::Web::Form->new( 'das_wizard', "/$ENV{ENSEMBL_SPECIES}/dasconfview", 'post'); 
    

# Check that a user has selected at least one source. 
	$onSubmit = qq{
	    var rc = true;
	    var s = document.das_wizard.DASWizardStep.value;
	    var f = document.das_wizard;
	    var warning = 'You must select a source to proceed!';
	    if (s == 1) {
		rc = false;
		if (f.submitButton != '_das_Step') {
		    rc = true;
		} else {
		    if (f.DASuser_source.value != '') {
			rc = true;
		    } else {
			for (var i= 0; i < f.length; i++) {
			    var e = f.elements[i];
			    if (e.checked) {
				rc = true;
				break;
			    }
			}
		    }
		}
	    }
	
	    if (rc == false) {
		alert(warning);
	    }
	    return rc;
	};
    }
    $form->{_attributes}->{onSubmit} = $onSubmit;

    my @cparams = qw ( conf_script db gene peptide transcript c w h l vc_start vc_end region das_sources );
    foreach my $param (@cparams) {
	my @vals = $object->param($param);
	if (scalar(@vals) > 0) {
	    foreach my $v (@vals) {
		$form->add_element('type'=>'Hidden', 'name' => $param, 'value' => $v );
	    }
	}
    }

    no strict 'refs';
    my $fname = "das_wizard_".$step;

    if (defined (my $error = &{$fname}($form, \%source_conf, $object, \$step))) {
	$step --;
	$fname = "das_wizard_".$step;
	&{$fname}($form, \%source_conf, $object, \$step, $error);
    }

    &wizardTopPanel($form, $step, $source_conf{sourcetype});

    $form->add_element('type'=>'Hidden','name' =>'DASWizardStep','value' => $step );

    
    my @sparams; 
    if ($step == 1) {
	@sparams = grep { /^DAS/ && /edit|link|enable|type|name|label|help|color|group|strand|depth|labelflag|stylesheet|score|^fg_/} $object->param();
    } elsif ($step == 2) {
	@sparams = grep { /^DAS/ && /edit|link|user_|sourcetype|protocol|domain|dsn|registry|dsns|paste_data|name|label|help|color|group|strand|depth|labelflag|stylesheet|score|^fg_/} $object->param();
	push @sparams, 'DAStype' if ($source_conf{sourcetype} eq 'das_file' && (! $object->param("DASdsn")));
    } elsif ($step == 3) {
	@sparams = grep { /^DAS/ && /edit|user_|protocol|domain|dsn|registry|dsns|paste_data|enable|type/} $object->param();
    }
    foreach my $param (@sparams) {
        my @v = $object->param($param);
        foreach my $op (@v) {
            $form->add_element( 'type'=>'Hidden', 'name' => $param,'value' => $op );
        }
    }
 
    $panel->add_columns({ 'key' => 'info', 'title' => ' '    });
#    $panel->add_row( {"info"=>$html} );
    $panel->add_row( {"info"=> $form->render()} );

    return 1;
}


sub added_sources {
    my( $panel, $object ) = @_;

    my $das_collection = $object->get_DASCollection;
    my @das_objs = @{$das_collection};
    my @das_form = ();
    my @url_form = ();

## Sources sorted by type and then by name
    foreach my $das_obj( sort{ ( 3 * ( $b->adaptor->conftype cmp $a->adaptor->conftype ) +  1 * ( lc( $a->adaptor->name ) cmp lc( $b->adaptor->name ))) } @das_objs ){
        my $das_adapt = $das_obj->adaptor;
        my $das_name = $das_adapt->name();
    
        my $das_action = '';
        if( $das_adapt->conftype eq 'internal' ){ # internal DAS source : configured within INI file
            $das_action = '&nbsp;';
        } elsif( $das_adapt->conftype eq 'url' ){ # URL DAS source : no edit, only delete
            my $das_action = sprintf("<a href=\"%s;_urldas_delete=%s\"><image src=\"/img/buttons/del_small.gif\" alt=\"Delete source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
        } else{ # Read-write source; Provide del/edit buttons
            my $delete_link = sprintf("<a href=\"%s;_das_delete=%s\"><image src=\"/img/buttons/del_small.gif\" alt=\"Delete source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
            my $edit_link = sprintf("<a href=\"%s;_das_edit=%s\"><image src=\"/img/buttons/edit_small.gif\" alt=\"Edit source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
            $das_action = $edit_link.$delete_link;
        }

	my @cparams = qw ( conf_script db gene peptide transcript c w h l vc_start vc_end region);
	my $url = sprintf("http://%s%s/%s/%s?",
			  $ENV{'SERVER_NAME'},
			  $ENV{'ENSEMBL_PORT'} ? ($ENV{'ENSEMBL_PORT'} == 80 ? '' : ":$ENV{'ENSEMBL_PORT'}") : '',
			  $ENV{'ENSEMBL_SPECIES'},
			  $object->param('conf_script'));

	foreach my $param (@cparams) {
	    if (defined(my $v = $object->param($param))) {
		$url .= "$param=$v;" if ($v);
	    }
	}

	my $add_link = sprintf("%sadd_das_source=(name=%s+url=%s+dsn=%s+type=%s",
			       $url, 
			       $das_name,
			       $das_adapt->domain,
			       $das_adapt->dsn,
			       $das_adapt->type,
			       );

	if ($das_adapt->color ne 'blue') {
	    $add_link .= '+color=';
	    $add_link .= $das_adapt->color;
	}
	
	if ($das_adapt->strand ne 'b') {
	    $add_link .= '+strand=';
	    $add_link .= $das_adapt->strand;
	}

	if ($das_adapt->labelflag ne 'u') {
	    $add_link .= '+labelflag=';
	    $add_link .= $das_adapt->labelflag;
	}

	if ($das_adapt->stylesheet ne 'n') {
	    $add_link .= '+stylesheet=';
	    $add_link .= $das_adapt->stylesheet;
	}

	if ($das_adapt->group ne 'y') {
	    $add_link .= '+group=';
	    $add_link .= $das_adapt->group;
	}

	if ($das_adapt->depth && ($das_adapt->depth != 10)) {
	    $add_link .= '+depth=';
	    $add_link .= $das_adapt->depth;
	}

	if ($das_adapt->score ne 'n') {
	    $add_link .= '+score=';
	    $add_link .= $das_adapt->score;
	}

	if ($das_adapt->fg_merge) {
	    $add_link .= '+fg_merge=';
	    $add_link .= $das_adapt->fg_merge;
	}

	if ($das_adapt->fg_grades){
	    $add_link .= '+fg_grades=';
	    $add_link .= $das_adapt->fg_grades;
	}
	
	if ($das_adapt->fg_data) {
	    $add_link .= '+fg_data=';
	    $add_link .= $das_adapt->fg_data;
	}

	if ($das_adapt->fg_max) {
	    $add_link .= '+fg_max=';
	    $add_link .= $das_adapt->fg_max;
	}

	if ($das_adapt->fg_min) {
	    $add_link .= '+fg_min=';
	    $add_link .= $das_adapt->fg_min;
	}
	if (my $link_url = $das_adapt->linkurl) {
	    $add_link .= '+linkurl=';
	    $link_url =~ s/\?/\$3F/g;
	    $link_url =~ s/\:/\$3A/g;
	    $link_url =~ s/\#/\$23/g;
	    $link_url =~ s/\&/\$26/g;
	    $add_link .= $link_url;
	}
	if (my $link_text = $das_adapt->linktext) {
	    $add_link .= '+linktext=';
	    $add_link .= $link_text;
	}

	$add_link .= '+active=1)';

	my $js = qq{javascript:X=window.open('','helpview','left=20,top=20,height=200,width=600,resizable');
	  X.document.write('
<html><title>Send DAS Source!</title>
<body onblur=window.close()>
<h3>If you want to share your source with someone send them the link below
</h3>
<br />
<small>
$add_link
</small>
</body>
</html>
');
          X.focus();
	  void(0)
} ;

	my $das_send = qq{<a href="$js"><image src="/img/buttons/mail.png" alt="Send source to a friend"/></a>};

        my $das_url = $das_adapt->domain;
        my $das_dsn = $das_adapt->dsn || '&nbsp;';
        my $das_type = $das_adapt->type ? $object->getCoordinateSystem($das_adapt->type) : '&nbsp';

# If type is 'mixed' then it is mixed mapping source
        if ($das_type eq 'mixed') {
            $das_type = join('+', map {$object->getCoordinateSystem($_)} @{$das_adapt->mapping});
        }

        if ($das_adapt->conftype eq 'url') {
            push @url_form, qq{
  <tr class="background3" valign="middle">
     <td>$das_action</td>
     <td style="padding:3px" >&nbsp;</td>
     <td colspan="3">$das_url</td>
  </tr>
};
        } else {
        push @das_form, {'action'=>$das_action, 'name'=> $das_name, 'url'=>$das_url, 'dsn'=>$das_dsn, 'type'=>$das_type, 'sendurl' => $das_send};
        }
            
    }
    
    $panel->add_columns(
                        { 'key' => 'action', 'title' => ' '    },
                        { 'key' => 'sendurl', 'title' => ' '    },
                        { 'key' => 'name', 'title' => 'Name'    },
                        { 'key' => 'location', 'title' => 'DAS Server' },
                        { 'key' => 'source', 'title' => 'Data Source'   },
                        { 'key' => 'mapping', 'title' => 'Coordinate System'  },
                        );

    foreach my $src (@das_form) {
        $panel->add_row( {
            'action' => $src->{action},
            'sendurl' => $src->{sendurl},
            'name' => $src->{name},
            'location' => $src->{url}, 
            'source' => $src->{dsn},
            'mapping' => $src->{type},
            '_raw' => $src
            });
    }


    return 1;
}

sub wizardTopPanel {
  my ($form, $step, $stype) = @_;

  my $snum = ($stype eq 'das_url') ? 1 : 3;

  my ($pstage, $nstage) = ();

  my $navigation = qq{
<div class="formblock">
  <div class="formpadding"></div>
  <div class="formpadding"></div>
    <div class="formcontent">
};

  if ($stype eq 'das_url') {
      $navigation .= qq{<input type="submit" name="_das_submit" value="$btnFinish" class="red-button" onClick="this.form.submitButton = this.name"/>};
  } else {
    if( $step > 1 ) {
	$navigation .= qq{<input type="submit" name="_das_Step" value="$btnBack" class="red-button" onClick="this.form.submitButton = this.name" /> &nbsp; &nbsp; &nbsp;};
    }
    if( $step < $snum ) {
	$navigation .= qq{<input type="submit" name="_das_Step" value="$btnNext" class="red-button" onClick="this.form.submitButton = this.name"  />};
    } else {
	$navigation .= qq{<input type="submit" name="_das_submit" value="$btnFinish" class="red-button" onClick="this.form.submitButton = this.name"  />};
    }
  }

  $navigation .= qq{
</div>
</div>
};

     $form->add_element('type' => 'Information', 'value' => $navigation);

  return 1;
}

sub das_wizard_2 {
    my ($form, $source_conf, $object, $step_ref, $error) = @_;

    my $error_section;
    my $set_mapping;
    my $source_type = $source_conf->{sourcetype};

    $source_type  = 'das_registry' if ($object->param('DASdomain') eq $object->species_defs->DAS_REGISTRY_URL);

    if ($source_conf->{sourcetype} eq 'das_file' && (! $object->param("DASdsn"))) {
	my $user_email = $object->param('DASuser_email');
	my $user_password = $object->param('DASuser_password');
	my $user_pastedata = $object->param('DASpaste_data');
	my $user_action = $object->param('DASuser_action');
# Validate email and password
       
	( length($user_password) > 0) or $error_section = qq{<strong>ERROR: Empty parameter: Password</strong>};
	
	($user_email =~ /\@/) or $error_section = qq{<strong>ERROR:Invalid format of Email</strong>};
	return $error_section if ($error_section);

	use EnsEMBL::Web::DASUpload;
	my $du  = EnsEMBL::Web::DASUpload->new($object);
	warn ("UA : $user_action");
	
	if (length($user_pastedata) > 0) {
	    $du->data($user_pastedata);
	} else {
	    $du->upload_data('DASfilename');
	}
	if (defined (my $err= $du->error)) { 
	    $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
	} else {
	    if (defined (my $err = $du->parse())) {
		$error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
	    } else {
		my ($fnum, $gnum);
		if (defined(my $user_dsn = $object->param("DASuser_dsn") || undef)) {
		    ($fnum, $gnum) = $du->update_dsn($user_dsn, $user_password, $user_action);
		} else {
		    ($fnum, $gnum) = $du->create_dsn($user_email, $user_password);
		}

		if (defined (my $err = $du->error)) {
		    $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
		} else {
		    my $domain = $du->domain;
		    my $dsn = $du->dsn;
		    if ($set_mapping = $du->metadata('coordinate_system')) {
			push @{$source_conf->{mapping}} , $set_mapping;
		    }

		    $source_conf->{type} = $set_mapping;			
		    $source_conf->{domain} = $domain;
		    $source_conf->{dsn} = $dsn;
		    $source_conf->{url} = join('/',$domain, $dsn);
			    
		    $object->param('DAStype', $set_mapping);
		    $object->param('DASdomain', $domain);
		    $object->param('DASdsns', $dsn);


		    my $css = $du->css ? 'Successfully uploaded stylesheet <br />' : '';
		    my $meta = $du->metadata('_XML') ? 'Successfully uploaded meta data <br />' : '';
		    my $groups = $gnum ? "Successfully uploaded $gnum groups <br/>" : '';
		    my $assembly = $du->metadata('assembly');
		    my $features = "Successfully uploaded $fnum features ". ($assembly ? "based on $assembly assembly" : ''). "<br/>";
		    if (defined(my $user_dsn = $object->param("DASuser_dsn") || undef)) {
			$$step_ref = 10;

			$form->add_element('type' => 'Information', 'value'=> qq{
			    $css
			    $meta
			    $groups
			    $features
			    DAS source at $domain/$dsn has been updated<hr/>
			    <br/>
			    <br/>
			});

		    } else {
			$form->add_element('type' => 'Information', 'value'=> qq{
			    $css
			    $meta
			    $groups
			    $features
			    A new DAS source has been created at $domain/$dsn<hr/>
			    <br/>
			    <br/>
			});
		    }
		}
	    }
	}

	return $error_section if ($error_section);
    }
    my $script = $object->param('conf_script');

    my %DefaultMapping =  (
                           'geneview' => 'ensembl_gene',
                           'protview' => 'ensembl_peptide',
                           'transview' => 'ensembl_gene', # Coz there is no ensembl_transcript source around at the moment
                           'contigview' => 'ensembl_location',
                           'cytoview' => 'ensembl_location'
                           );
       
    if ($source_type eq 'das_registry') {
	my $cs_html = qq{
<div class="formblock">
  <h6><label>Coordinate System</label></h6>
    <div class="formcontent">
    &nbsp;&nbsp;&nbsp;Provided by Registry
    </div>
  </div>
};
        $form->add_element('type'=>'Information', 'value'=> $cs_html);
    } else {
	if ($source_conf->{sourcetype} eq 'das_file' && $set_mapping) {
	    my $cs = join('<br/>', map {$object->getCoordinateSystem($_)} grep {$_} @{$source_conf->{mapping}}) ;

	    my $cs_html = qq{
<div class="formblock">
  <h6><label>Coordinate System </label></h6>
    <div class="formcontent">
    &nbsp;&nbsp;&nbsp;$cs
    </div>
  </div>
};
	    $form->add_element('type'=>'Information', 'value'=> $cs_html);
	} else {
	    my @mvalues;
# grep is to filter out undef elements
	    my @seltypes = grep {$_} @{$source_conf->{mapping}};
	    if (scalar(@seltypes) < 1) {
		push @seltypes, $DefaultMapping{$script};
	    }

	    my %DASMapping = %{$object->getCoordinateSystem};
	    my $ptest = join('*', @seltypes).'*';
	    foreach my $p (sort keys (%DASMapping)) {
		if ($ptest =~ /$p\*/){
		    push @mvalues, {"value"=>$p, "name"=>$DASMapping{$p}, "checked"=>"yes"};
		} else {
		    push @mvalues, {"value"=>$p, "name"=>$DASMapping{$p}};
		}
	    }
	    $form->add_element('type' => 'MultiSelect',
			       'class' => 'radiocheck1col',
			       'name'=>'DAStype',
			       'label'=>'Coordinate System',
			       'values' => \@mvalues
			       );
	}
    }
    my @views = ('geneview', 'protview', 'transview', 'contigview', 'cytoview');

    my %selviews = ();
    if (@{$source_conf->{enable}}) {
        foreach (@{$source_conf->{enable}}) {
            $selviews{$_} = 1;
        }
    }

    $selviews{$script} = 1;

    my @vvalues;
    foreach my $v (@views) {
        if ($selviews{$v}) {
            push @vvalues, {"value"=>$v, "name"=>$v, "checked"=>"yes"};
        } else {
            push @vvalues, {"value"=>$v, "name"=>$v};
        }
    }
    $form->add_element(
		       'type' => 'MultiSelect',
                       'name'=>'DASenable',
                       'label'=>'Enable on',
                       'values' => \@vvalues
                       );
    return;
}

sub das_wizard_3 {
    my ($form, $das_conf, $object, $step_ref, $error) = @_;

    my $html = qq{<table id="display_config">\n};
    my $option;

    if ($das_conf->{scount} && $das_conf->{scount} > 1) {

	$option = $das_conf->{name};
	my $ht = qq{
<div class="formblock">
  <h6><label>Name:</label></h6>
    <div class="formcontent">
    &nbsp;&nbsp;&nbsp;$option
    </div>
  </div>
};

	$option = $das_conf->{label} || $option;

	$ht .= qq{
<div class="formblock">
  <h6><label>Label:</label></h6>
    <div class="formcontent">
    &nbsp;&nbsp;&nbsp;$option
    </div>
  </div>
};

	$form->add_element('type'=>'Information', 'value'=> $ht);
    } else {
	$option = $das_conf->{name} || $das_conf->{user_source} || $das_conf->{dsn};
	$form->add_element('type'=>'String', 'name'=>'DASname', 'label'=>'Name:', 'value'=> $option);
	$option = $das_conf->{label} || $option;
	$form->add_element('type'=>'String', 'name'=>'DASlabel', 'label'=>'Track label:', 'value'=> $option);
    }

    $option = $das_conf->{help} || '';
    $form->add_element('type'=>'String', 'name'=>'DAShelp', 'label'=>'Help URL:', 'value'=> $option);
    $option = $das_conf->{linktext} || '';
    $form->add_element('type'=>'String', 'name'=>'DASlinktext', 'label'=>'Link Text:', 'value'=> $option);
    $option = $das_conf->{linkurl} || '';
    $form->add_element('type'=>'String', 'name'=>'DASlinkurl', 'label'=>'Link URL:', 'value'=> $option);

    $option = $das_conf->{color} || 'blue';

    use Bio::EnsEMBL::ColourMap;
    my $cm = new Bio::EnsEMBL::ColourMap($object->species_defs);
    my @cvalues;
    for $_ (sort keys %$cm) { ## OPTIONS IN DROP DOWN FOR COLOURS
        my $id = $cm->{$_};
        push @cvalues, {'name'=>$_, 'value'=>$_};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DAScolor',
                       'label'=>'Track colour',
                       'values'=>\@cvalues,
                       'value' => $option
                       );


    $option = lc($das_conf->{group} || 'n');
    my @gvalues;
    foreach ( 'Yes', 'No' ) {
        my $id          = lc(substr($_,0,1));
        push @gvalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASgroup',
                       'label'=>'Group features',
                       'values'=>\@gvalues,
                       'value' => $option
                       );

    $option = lc($das_conf->{strand} || 'b');
    my @svalues;
    foreach ( 'Forward strand', 'Reverse strand', 'Both strands' ) {
        my $id          = lc(substr($_,0,1));
        push @svalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASstrand',
                       'label'=>'Display on:',
                       'values'=>\@svalues,
                       'value' => $option
                       );

    ## OPTIONS IN DROP DOWN FOR BUMPEDNESS
    $option = defined($das_conf->{depth}) ?  $das_conf->{depth} : 10;
    my @dvalues;
    foreach  ( 0..6,10,20,10000 ) {
        my $id          = $_==0 ? 'Collapse display' : ($_==10000 ? 'Unlimited' : "$_ rows" );
        push @dvalues, {'name'=>$id, 'value'=>$_};
    }

    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASdepth',
                       'label'=>'Max rows to display:',
                       'values'=>\@dvalues,
                       'value' => $option
                       );

  ## OPTIONS IN DROP DOWN FOR LABELLING
    $option = lc($das_conf->{labelflag}|| 'u');
    my @lbvalues;
    foreach ( 'No label', 'On feature', 'Under feature' ) {
        my $id          = lc(substr($_,0,1));
        push @lbvalues, {'name'=>$_, 'value'=>$id};
    }

    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASlabelflag',
                       'label'=>'Label features:',
                       'values'=>\@lbvalues,
                       'value' => $option
                       );


    $option = lc($das_conf->{stylesheet} || 'n');
    my @stvalues;
    foreach ( 'Yes', 'No' ) {
        my $id          = lc(substr($_,0,1));
        push @stvalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASstylesheet',
                       'label'=>'Apply stylesheet:',
                       'values'=>\@stvalues,
                       'value' => $option
                       );

    $option = lc($das_conf->{score} || 'n');
    my @scvalues;
    my @ctypes = ( 'n' => 'No chart', 'h' => 'Histogram', 's' => 'Tiling Array','c' => 'Colour gradient' );

    do {
	my $id = shift @ctypes;
	my $label = shift @ctypes;
        push @scvalues, {'name'=>$label, 'value'=>$id};
    } while (@ctypes);

    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASscore',
                       'label'=>'Score chart:',
                       'values'=>\@scvalues,
                       'value' => $option,
		       'on_change' => 'submit'
		       );
	
    if ($option eq 'c') {
	$option = $das_conf->{fg_grades} || 20;
	$form->add_element('type'=>'String', 'name'=>'DASfg_grades', 'label'=>'Grades:', 'value'=> $option);

 	my @dtypes = ('o' => 'Original', 'n' => 'Normalize');

    	$option = lc($das_conf->{fg_data} || 'o');
    	my @dvalues;

    	do {
		my $id = shift @dtypes;
		my $label = shift @dtypes;
        	push @dvalues, {'name'=>$label, 'value'=>$id};
    	} while (@dtypes);

    	$form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASfg_data',
                       'label'=>'Data:',
                       'values'=>\@dvalues,
                       'value' => $option,
		       'on_change' => 'submit'
		       );
	
	if ($option eq 'l') {
		$option = $das_conf->{fg_max} || 100;
		$form->add_element('type'=>'String', 'name'=>'DASfg_max', 'label'=>'Max score:', 'value'=> $option);
		$option = $das_conf->{fg_min} || 0;
		$form->add_element('type'=>'String', 'name'=>'DASfg_min', 'label'=>'Min score:', 'value'=> $option);
        }

    } elsif ($option eq 'h') {
	$option = lc($das_conf->{fg_merge} || 'a');
	my @scvalues;
	foreach ( 'Average Score', 'Max Score') {
	    my $id          = lc(substr($_,0,1));
	    push @scvalues, {'name'=>$_, 'value'=>$id};
	}
	$form->add_element('select'=>'select',
			   'type'=>'DropDown',
			   'name'=>'DASfg_merge',
			   'label'=>'Merged features score:',
			   'values'=>\@scvalues,
			   'value' => $option
			   );

    }
 
    return;
}

sub wizard_search_box {
    my ($form, $source_conf, $object, $cs_box) = @_;

    my %DASMapping = %{$object->getCoordinateSystem};
    $DASMapping{any} = 'Any';

# Decide whether to display Coordinate System filter.
# ATM the registry can provide this info but the sources themselves can not - hence we display the drop-down only for the registry 


    my $mapping_form = $cs_box ? sprintf("
       <tr> <td nowrap><b>Coordinate System:</b></td><td>%s</td> </tr>", 
       _formelement_select($object, "keyMapping", [ sort keys (%DASMapping) ], {%DASMapping})) : '';
    my $das_action = qq{<input type="submit" name="_das_filter" value="Apply" class="red-button" onClick="this.form.submitButton = this.name"/>};


    my $search_box = qq{
<div class="formblock">
  <br />
  <br />

  <h6><label>Available DAS sources on the selected server</label></h6>
  <br />
  <h6><label>(use the filter to narrow the list of sources)</label></h6>
    <div class="formcontent">

<table style="border:0">
  <tr>
    <td nowrap><b>Name/URL/Description:</b></td><td><input type="text" name="keyText"/></td>
    <td rowspan="2" valign="middle">$das_action</td>
  </tr>
  $mapping_form
</table>
    </div>
</div>
};

    $form->add_element( 'type'=>'Information', 'value'=> $search_box );
    
}

sub add_das_registry {
  my ($form, $source_conf, $object) = @_;

  my $rurl = $object->species_defs->DAS_REGISTRY_URL;

  wizard_search_box ($form, $source_conf, $object, 1);

  my %selected_sources = ();
  if (defined($source_conf->{registry_selection})) {
      foreach (@{$source_conf->{registry_selection}}) {
	  $selected_sources{$_} = 1;
      }
  }

  my $registry = $object->getRegistrySources();

  $rurl .= "/showdetails.jsp?auto_id=";

  my $dwidth = 120;
  my $html = qq{<table>};
  foreach my $id (sort {$registry->{$a}->{nickname} cmp $registry->{$b}->{nickname} } keys (%{$registry})) {
    my $dassource = $registry->{$id};
    my ($id, $name, $url, $desc, $cs) = ($dassource->{id}, $dassource->{nickname}, $dassource->{url}, substr($dassource->{description}, 0, $dwidth), join('*', @{$dassource->{coordinateSystem}}));
    $cs = qq{<a href="javascript:X=window.open(\'$rurl$id\', \'DAS source details\', \'left=50,top=50,resizable,scrollbars=yes\');X.focus();void(0)">details about \`$name\`</a>};
    my $selected = $selected_sources{$id} ? 'checked' : '';
    
    if( length($desc) == $dwidth ) {
# find the last space character in the line and replace the tail with ...        
      $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./;
    }
    $html .= qq{\n  <tr><td><input type="checkbox" name="DASregistry" value="$id" $selected ></td><td>$name</td><td><b>$url</b><br>$desc<br>$cs</td></tr>};
  }

  $html .= qq{\n</table>\n};

  $form->add_element( 'type'=>'Information', 'value'=> $html );
  return;
}

sub add_das_file {
  my ($form, $source_conf, $object, $step_ref, $error_section) = @_;

  $form->add_element( 
    'type'  => 'Information',
    'value' => 'Please upload your data location'
  );
  if( $error_section ) {
    $form->add_element(
      'type'  => 'Information',
      'value' => $error_section
    );
  }
  $form->add_element(
    'type'  => 'Information',
    'value' => qq{
  <p>
   Please <strong><a href="javascript:X=window.open('/$ENV{ENSEMBL_SPECIES}/helpview?se=1&kw=dasconfview#Upload','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">READ THE UPLOAD INSTRUCTIONS CAREFULLY</a></strong> before uploading any data. Your data must be <a href="javascript:X=window.open('/$ENV{ENSEMBL_SPECIES}/helpview?se=1&kw=dasconfview#UploadFormat','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">formatted correctly</a> before uploads will work properly. The instructions page has detailed information about the data formats.
  </p>
  <p>
    Please read and understand the <a href="javascript:X=window.open('/$ENV{ENSEMBL_SPECIES}/helpview?se=1&kw=dasconfview#Disclaimer','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">Ensembl policy on uploaded data</a>
  </p>
  <hr />
});

  $form->add_element(
    'required' => 'yes',
    'type'  => 'Email',
    'name'  => 'DASuser_email',
    'label' => 'Email',
    'value' => $object->param('DASuser_email')
  );

  $form->add_element(
    'type'  => 'String',
    'name'  => 'DASuser_password',
    'label' => 'Password',
    'value' => $object->param('DASuser_password'),
    'notes' => '<small>Enter your email and password to ensure that nobody else can modify your annotation</small>'
  );

  $form->add_element(
    'type'  => 'Text',
    'name'  => 'DASpaste_data',
    'label' => 'Paste your data'
  );
  $form->add_element(
    'type'  => 'Information',
    'value' => 'or choose a file to upload'
  );
  $form->add_element(
    'type'  => 'File',
    'name'  => 'DASfilename',
    'label' => "Upload File:"
  );

  $form->add_element(
    'type'  => 'Information',
    'value' => qq{
  <p>
   <br/>
   <b>If you want to update an existing annotation on Ensembl DAS Server enter its Data Source Name and select your action
  </b>
  </p>
  <hr/>
});

  $form->add_element(
    'type'  => 'String',
    'name'  => 'DASuser_dsn',
    'label' => 'Data source',
    'value' => $object->param('DASuser_dsn'),
  );

  $object->param('DASuser_action') || $object->param('DASuser_action', 'append');

  $form->add_element(
    'type'   => 'DropDown',
    'name'   => 'DASuser_action',
    'label'  => 'Action',
    'values' => [
      { 'name' => 'Overwrite', 'value' => 'overwrite' },
      { 'name' => 'Append',    'value'  => 'append'    }
    ],
    'value' => $object->param('DASuser_action'),
  );


  return;
}

1;
