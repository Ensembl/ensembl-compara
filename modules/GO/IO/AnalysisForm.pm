# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::IO::AnalysisForm;

=head1 NAME

  GO::IO::AnalysisForm     - Gene Ontology Blast Reports

=head1 SYNOPSIS



=cut



=head1 DESCRIPTION

stage - EXPERIMENTAL

still requires BDGP code

=head1 PUBLIC METHODS - Blast


=cut

use GO::AppHandle;
use GO::IO::Blast;
use Pipeline::Config qw(:states);
use Pipeline::FastaDatabase;
use Pipeline::Manager;

sub new {
    my $proto = shift; my $class = ref($proto) || $proto;;
    my $self= {};
    bless $self, $class;
    $self->config(Pipeline::Config->new);
    return $self;
}

sub config {
    my $self = shift;
    $self->{_config} = shift if @_;
    return $self->{_config};
}


sub cgi {
    my $self = shift;
    $self->{_cgi} = shift if @_;
    return $self->{_cgi};
}

sub process {
    my $self = shift;
    my $cgi = $self->cgi;
    $self->out($cgi->header);
    $self->out($cgi->start_html('-title'=>"blast",
				-BGCOLOR=>"#FFFFFF"));
    my $submit = $self->cgi->param("Action");
    if ($submit) {
	if ($submit eq "blast") {
	    $self->initiate_analyses();
	}
	elsif ($submit eq "monitor") {
	    $self->monitor_analyses();
	}
	else {
	}
    }
    else {
	$self->initialize_form;
    }
}

sub initialize_form {
    my $self = shift;
    my $cgi = $self->cgi;
    my $config = $self->config;
    
    $self->out($cgi->start_form(-method=>"GET"));

##    my @list = $config->fastadb_nickname_list;

    $self->out($cgi->textarea(-name=>"residues", -rows=>10, -cols=>80));
    $self->out($cgi->p().$cgi->textfield(-name=>"args", -length=>50));
    $self->out($cgi->submit('Action', 'blast'));
    $self->out($cgi->end_form);
}

sub initiate_analyses {
    my $self = shift;
    
    my $cgi = $self->cgi;
    my $config = $self->config;
    
    my $program = $cgi->param("program") || "blastp";

    my $mgr = Pipeline::Manager->new;
    my $job;
    eval {
        $job =
          $mgr->launch_new_job(
                               -residues=>$cgi->param('residues'),
                               -subjectdb=>"/www/whitefly_80/WWW/annot/go/fasta/go_pep.fa",
                               -use_pbs=> defined($cgi->param("use_pbs")) ? $cgi->param("use_pbs") : 0,
                               -program=>$program,
                               -args=>$cgi->param("args"),
                               -comments=>"goblast job",
                              );
    };
    if ($@) {
        print "<h1>ERROR:$@</h1>";
        return;
    }

    $self->out($cgi->start_form(-method=>"GET"));
    $self->out($self->widget_monitor($job->analysis->batch_id));
    #print $job->analysis->batch_id;
    $self->out($cgi->end_form);
    $job->analysis->manager->get_pipe_dbh->disconnect;
}

sub widget_monitor {
    my $self = shift;
    my $batch_id = shift;
    my $cgi = $self->cgi;
    return 
      $cgi->textfield(-name=>"batchID", -default=>$batch_id).
	$cgi->submit('Action', 'monitor').
	  $cgi->popup_menu(-name=>"report", -values=>[qw(detail summary)]);
}

sub monitor_analyses {
    my $self = shift;
    
#    $ENV{SQL_TRACE}=1;
#    $ENV{PIPE_DEBUG}=1;

    my $cgi = $self->cgi;
    my $config = $self->config;

    my $mgr = Pipeline::Manager->new;

    my $batch_id = $cgi->param("batchID");
    my $hl;
    if ($batch_id) {
	eval {
	    $mgr->monitor_batch($batch_id, -advance_to=>'FIN');
	};
	if ($@) {
	    print $@;
	}
	$hl = $mgr->batch_status($batch_id);
    }
    else {
	$hl = $mgr->seq_status($cgi->param("seq"));
    }
    $self->out($cgi->table({-border=>1},
			   $cgi->caption('Blast DBs'),
			   $cgi->Tr({-align=>'CENTER',-valign=>'TOP'},
				    [
				     $cgi->th([]),
				     map {
					 my $t = localtime($_->{'created'});
					 $cgi->td([
						   $_->{program},
						   $t,
						   $_->{'dsname'},
						   $_->{'state'},
						   $_->{'n'},
						  ])
				     } @$hl,
				    ]
				   )
			  ));
    
    $self->out($cgi->start_form(-method=>"GET"));

    foreach my $h (@$hl) {
	if ($h->{'state'} eq $STATE_RUN) {
	}
	elsif ($h->{'state'} eq $STATE_FAIL) {
	}
	else {
	    unless($cgi->param("report") && 
		   $cgi->param("report") eq "summary") {
		my $an = $mgr->get_analysis({id=>$h->{'id'}});
		my $jobs = $an->get_jobs({analysis_id=>$an->id});
		# if submitted via webblast form, should
		# only be one
		$self->format_results($jobs);
	    }
	}
    }


    $self->out($cgi->popup_menu(-name=>"format",
				-values=>[qw(text xml graphical)]));
    $self->out($cgi->popup_menu(-name=>"parser",
				-values=>[qw(perl bop)]));
				
    $self->out($self->widget_monitor($batch_id));
    $self->out($cgi->end_form);

}

sub raw2html {
    my $self = shift;
    my $raw = shift;
    my $blast = GO::IO::Blast->new({apph=>$self->get_apph});
    $blast->getgraph($raw);
    $self->out("<pre>".$blast->output."</pre>");
    $self->out("<pre>$raw</pre>");
}

sub format_results {
    my $self = shift;
    my $jobs = shift;
    my $format = $self->cgi->param("format");
    if (!$format || $format eq "text") {
	foreach my $job (@$jobs) {
	    my $output = $job->raw_result_output;
	    $self->out($self->raw2html($output));
	}
    }
    elsif ($format eq "graphical") {
	$self->out("<p>not ready yet<p>");
    }
    else {
	$self->out("<p>format $format not recognised<p>");
    }
}

sub out {
    my $self = shift;
    print @_;
}

sub get_apph {
    my $self = shift;
    if (!defined($self->{_apph})) {
        $self->{_apph} =
          GO::AppHandle->connect(-dbname=>"go",
                                 -dbhost=>"headcase");
    }
    return $self->{_apph};
}

1;

