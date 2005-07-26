# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::DatabaseLoader;

=head1 NAME

GO::DatabaseLoader

=head1 SYNOPSIS

my $builder = GO::DatabaseLoader->new;
my $parser = GO::Parser->new($builder);

=head1 DESCRIPTION

This inherits from GO::Builder

=head1 FEEDBACK

Email 

cjm@fruitfly.org
ihh@fruitfly.org

=head1 INHERITED METHODS

=cut

use strict;
use GO::Utils qw(rearrange dd);
use GO::Builder;
use GO::Model::Evidence;
use FileHandle;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
use GO::SqlWrapper qw(:all);

@ISA = qw(GO::Builder Exporter);
@EXPORT_OK = qw(get_handle add_term get_term add_relationship retire_term
	       add_dbxref undo_changes undo get_new_goid disconnect);
%EXPORT_TAGS = (all=> [@EXPORT_OK]);

sub _initialize 
{

    my $self = shift;
    $self->SUPER::_initialize(@_);
    my $paramh = shift;
    my @valid_params = $self->_valid_params;
    map {
	if (defined($paramh->{$_})) {
	    $self->{$_} = $paramh->{$_};
	}
    } @valid_params;
#    if (!$self->{type}) {
#	confess("need type");
#    }
    if (!$self->{user}) {
	confess("need user");
    }
}

sub _valid_params {
    ("apph", "user");
}


=head1 PUBLIC METHODS

=cut

=head2 get_new_goid

=cut

sub get_new_goid {
    my ($self) = @_;
    return ($self->apph->generate_goid($self->{user}));
}

sub apph {
    my $self = shift;
    $self->{apph} = shift if @_;
    return $self->{apph};
}

=head2 add_term

  Usage   - $t = $loader->add_term({acc=>$acc, name=>$name, type=>"function"})
  Returns - GO::Model::Term
  Args    - term hashref (or object)

=cut

sub add_term {
    my ($self, $termh) = @_;
    if (!ref($termh)) {
	confess("$termh - argument must be hashref or obj");
    }
    my $t = $self->apph->get_term({%$termh}, {id=>1});

    if (!$t) {
	eval {
	    $t =
	      $self->apph->add_term($termh, $self->{user});
	    $self->apph->commit;
	};
	if ($@) {
	    $self->warn("couldn't add term $termh id=$termh->{acc} (maybe duplicates?)".
			"\n$@");
	}
    }
    else {
	# $self->warn ("$termh exists - updating\n");
      $self->apph->update_term($t, $self->{user}, "update");
    }
    return $t;
}

=head2 add_dbxref

=cut

sub add_dbxref {
    my ($self, $id, $xrefkey, $xrefdbname) = @_;
    my $h = {xref_key=>$xrefkey, xref_dbname=>$xrefdbname};
    my $t = $self->apph->get_term({acc=>$id}, {id=>'y'});

    if ($t) {
	eval {
	  $self->apph->add_term_dbxref($t, $h);
	};
	if ($@) {
	    $self->warn("couldn't add xref ".$xrefdbname.":".$xrefkey.
			" to ".$t->{name}.
			"\n$@");
	}
    }
    else {
	$self->warn("Can't add ".$xrefdbname.":".$xrefkey." to a term that doesn't exist yet ($id) !");
    }
}

sub set_category {
    my ($self, $id, $category) = @_;
#    $self->warn ("Ignored: term $id category is '$category'\n");
}

sub add_obsolete_pointer {
    my ($self, $id, $obsolete_id) = @_;
    eval {
#	$self->apph->replace_term({acc=>$obsolete_id}, 
#				  {acc=>$id},
#				  $self->{user});
	$self->apph->add_synonym(-term=>{acc=>$id},
				 -synonym=>sprintf("GO:%07d", $obsolete_id),
				 -user=>$self->{user});
    };
    if ($@) {
	$self->warn("Couldn't replace term ".$obsolete_id."\n");
    }
}

sub add_relationship {
    my $self = shift || confess;
    my $from_id = shift || confess "no from-acc";
    my $to_id = shift || confess "no to-acc";
    my $type = shift;

    my $rel_l = $self->apph->get_relationships({acc1=>$from_id,
						acc2=>$to_id});
    my $rel = $rel_l->[0]; #there is only one!
    #Chris: without type when add_relation, 'developsfrom' becomes other type
    #but with type, 'is' type become another relationship type, so Parser
    #will interpret % as 'isa' rather than 'is' -- Shu
    if (!$rel) {
	eval {
	  $self->apph->add_relation({acc1=>$from_id,
				   acc2=>$to_id,
				   is_inheritance=>(($type eq "is" or $type eq "isa")? 1:0),
                   type=>$type},
				  $self->{user});
	};
	if ($@) {
	    $self->warn("Problem with add_relationship ".
			"(maybe $from_id/$to_id not entered yet)\n$@\n");
	}
    }
    else {
	if ($rel->type !~ /$type/) {
	    $self->warn ("relationship exists - ignoring, ".
			 "but $type doesn't match existing type "
			 .$rel->type." between $from_id and $to_id\n");
	}
    }
}

sub add_synonym {
    my ($self, $id, $synonym) = @_;
    eval {
      $self->apph->add_synonym({acc=>$id},
			     $synonym,
			     $self->{user});
    };
    if ($@) {
	$self->warn("problem with add_synonym: $@");
    }
}

sub add_association {
    my $self = shift;
    my $assoc = shift;
    eval {
	$self->apph->add_association($assoc);
    };
    if ($@) {
	$self->warn("problem with add_association: $@");
    }
    
}

sub add_definition {
    my $self = shift;
    my $def_h = shift;
    my $xref_h = {};
    
    if ($def_h->{ref_arr}) {

	my $isbn_pattern = q/\s*ISBN\s*:\s*(\d+)/;
	my $pmid_pattern = q/\s*PMID\s*:\s*(\d+)/;
	my $medline_pattern = q/\s*MEDLINE\s*:\s*(\d+)/;
	my $ec_pattern = q/\s*ENZYME:\s*EC\s*[:\.]?\s*([0-9\.\-]+)/;
	my $fbdb_pattern = q/\s*FlyBase\s*:\s*([A-Za-z0-9_]+)/;
	my $fb_pattern = q/\s*fb\s*:\s*([A-Za-z0-9_]+)/;
	my $sgd_pattern = q/\s*sgd\s*:\s*([A-Za-z0-9_]+)/;
	my $gxd_pattern = q/\s*gxd\s*:\s*([A-Za-z0-9_]+)/;
	my $go_pattern = q/\s*go\s*:\s*([A-Za-z0-9_]+)/;
	my $pub_pattern = q/\s*publication\s*:\s*([A-Za-z0-9_]+)/;
	my $omim_pattern = q/\s*OMIM\s*:\s*([A-Za-z0-9_]+)/;
	my $embl_pattern = q/\s*EMBL\s*:\s*([A-Za-z0-9_]+)/;
	my $sp_pattern = q/\s*SP\s*:\s*([A-Za-z0-9_]+)/;

	foreach my $ref (@{$def_h->{ref_arr}}) {
	    $xref_h->{xref_keytype} = "acc";
	    if ($ref =~ /$isbn_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "isbn";
	    }
	    elsif ($ref =~ /$pmid_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "pmid";
	    }
	    elsif ($ref =~ /$medline_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "medline";
	    }
	    elsif ($ref =~ /$isbn_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "isbn";
	    }
	    elsif ($ref =~ /$ec_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "ec";
	    }
	    elsif ($ref =~ /$embl_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "embl";
	    }
	    elsif ($ref =~ /$sp_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "sp";
	    }
	    elsif ($ref =~ /$omim_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "omim";
	    }
	    elsif ($ref =~ /$fbdb_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "fb";
	    }
	    elsif ($ref =~ /$fb_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "fb";
		$xref_h->{xref_keytype} = "personal communication";
	    }
	    elsif ($ref =~ /$sgd_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "sgd";
		$xref_h->{xref_keytype} = "personal communication";
	    }
	    elsif ($ref =~ /$gxd_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "gxd";
		$xref_h->{xref_keytype} = "personal communication";
	    }
	    elsif ($ref =~ /$go_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "go";
		$xref_h->{xref_keytype} = "personal communication";
	    }
	    elsif ($ref =~ /$pub_pattern/) {
		($xref_h->{xref_key}) = $1;
		$xref_h->{xref_dbname} = "publication";
		$xref_h->{xref_keytype} = "citation";
	    }
	    elsif ($ref =~ /(\w+):(.*)$/) {
		($xref_h->{xref_key}) = $2;
		$xref_h->{xref_dbname} = $1;
		$xref_h->{xref_keytype} = "acc";
		if ($1 eq "http") {
		    $xref_h->{xref_keytype} = "url";
		}
	    }
	    else {
		$self->warn ("don't recognize ".
			     $ref."\n");
	    }
	}
    }
    eval {
      $self->apph->add_definition($def_h, $xref_h);
    };
    if ($@) {
	$self->warn("problem with add_definiton: $@");
    }

}

sub commit_changes {
    my $self = shift;
    $self->apph->commit;
}

sub disconnect {
    my $self = shift;
#    warn("deprecated");
    $self->apph->disconnect if $self->apph;
}


#
sub parse_defs_file {
    my $builder = shift;
    my ($fn) = @_;
    
    
    my @attrs = qw(term goid definition definition_reference);
    my $number_of_attrs = scalar(@attrs);
    my $fh = FileHandle->new($fn) || confess("cant open $fn");
    my $h = {};
    my ($attr, $val);
    while (<$fh>) {
	chomp;
	if (/^\!/) {
	    next;
	}
	if (!$_) {
	    if (%$h) {
		$builder->add_definition($h);
	    }
	    $h = {};
	    ($attr, $val) = ();
	    next;
	}
	if (!(/:/) && $attr) {
	    $h->{$attr} .= " ".$_;
	    next;
	}
	else {
	    ($attr, $val) = ();
	    for (my $i=0; $i < @attrs && !$val; $i++) {
		$attr = $attrs[$i];
		if (/^$attr:(.*)$/) {
		    $val = $1;
		}
	    }
	    if ($val) {
		if ($attr !~ /definition_reference/) {
		    $val =~ s/(GO:|FBbt:)//;
		    #remove leading spaces
		    $val =~ s/^\s*//;
		    $val =~ s/\s*$//;
		    $h->{$attr} = $val;
		}
		else {
		    if (!$h->{"ref_arr"}) {
			$h->{"ref_arr"} = [];
		    }
		    push (@{$h->{"ref_arr"}}, $val);
		}
	    }
	    else {
		$builder->warn ("unknown attr in line $_ for ".$h->{term}."\n");
		$h = {};
		($attr, $val) = ();
	    }
	}
    }
    if (%$h) {
#		my @keys = keys %$h;
#		foreach my $k (@keys) {
#		    print STDOUT ($k."=".$h->{$k}." ");
#		}
#		print STDOUT ("\n");
	$builder->add_definition($h);
    }
    $fh->close;
}

#
sub parse_xrefs_file {
    my ($builder, $fn) = @_;
    my $apph = $builder->apph;
    my $fh = FileHandle->new($fn) || confess("cant open $fn");
    my $line_no = 0;
    my @errors = ();
    LINE: while (<$fh>) {
	$line_no++;
	my $line;
	eval {
	    $line = $_;
	    chomp;
	    if (/^\!/) {
		next LINE;
	    }
	    if (!$_) {
		next LINE;
	    }
	    if (!/^(\w+):(.*) \> GO:(.*)[ ]*; GO:(.*)$/) {
                push(@errors, 
                     {msg=>"Wrong format:$_",
                      line_no=>$line_no, line=>$line, file=>$fn});
		next LINE;
	    }
            my $acc = $4;
            my $name = $3;
            my $xref_key = $2;
            my $xref_db = $1;

            if ($acc =~ /(.*?)\,(.*)/) {
                $acc = $1;
                push(@errors, 
                     {msg=>"Bad format; ignoring this part:$2",
                      line_no=>$line_no, line=>$line, file=>$fn});
            }

            # check if both term and GO ID match
	    if (!$apph->check_term({acc=>$acc, name=>$name})) {
                my $term = $apph->get_term({acc=>$acc});
                if (!$term) {
                    $term =
                      $apph->get_term({synonym=>"GO:$acc"});
                    if ($term) {
                        $acc = $term->acc;
                    }
                    else {
                        my $t = $apph->get_term({name=>$name});
                        my $msg ="There is no term with acc $acc ($name)";
                        if ($t) {$msg.= " (did you mean ".$t->acc.")"}
                        push(@errors, 
                             {msg=>$msg,
                              line_no=>$line_no, line=>$line, file=>$fn});
                        next LINE;

                    }
                }
                else {
                
                    # flag a warning and carry on
                    push(@errors, 
                         {msg=>sprintf("Warning: mismatched term for $acc %s != %s; LOADING ANYWAY",
                                       $term->name, $name),
                          line_no=>$line_no, line=>$line, file=>$fn,
                          warning=>1});
                }
            }
	    $builder->add_dbxref($acc, $xref_key, $xref_db);
	    $builder->commit_changes();
	};
	if($@) {
	    push(@errors, {msg=>$@, line_no=>$line_no, line=>$line, file=>$fn});
	}
    }
    $fh->close;

    push(@errors, @{$builder->error_list || []});
    $builder->error_list([]);

    $builder->per_file_report("xrefs", $fn, \@errors);
    return @errors;
}

sub parse_assocs {
    my $builder = shift;
    my $apph = $builder->apph;
    my ($fn) = @_;
    my @errors = ();
    my @cols = qw(speciesdb acc symbol is_not goacc reference 
		  ev_code seq_acc aspect full_name synonym_list);
    my @mandatory_cols = qw(speciesdb acc goacc ev_code);
    my @ev_codes = GO::Model::Evidence->valid_codes;

    # i'm sure there is a more clever way to do this, but this should work
    my $ev_code_index = -1;
    for (my $i = 0; $i < @cols && $ev_code_index < 0; $i++) {
	if ($cols[$i] =~ /^ev_code$/) {
	    $ev_code_index = $i;
	}
    }

    my $product;
    my $term;
    my $assoc;
    my $line_no = 0;

    my $fh = FileHandle->new($fn) || confess("cant open $fn");
    while (<$fh>) {
        $line_no++;
	chomp;
	if (/^\!/) {
	    next;
	}
        # TAIR headers
        if (/^DB/ && $line_no == 1) {
            next;
        }
	if (!$_) {
	    next;
	}
        s/\\NULL//g;
	my @vals = split(/\t/, $_);
	my $h = {};
        
	my $line = $_;
	eval {
	    # normalise columns, and set $h
	    for (my $i=0; $i<@cols;$i++) {
		if (defined($vals[$i])) {

                    # remove trailing and
                    # leading blanks
		    $vals[$i] =~ s/^\s*//;
		    $vals[$i] =~ s/\s*$//;

                    # TAIR seem to be
                    # doing a mysql dump...
                    $vals[$i] =~ s/\\NULL//;
		}
		if ( ! (defined($vals[$i]) ) ||
		     (length ($vals[$i]) == 0) ) {
		    if ( grep(/$cols[$i]/, @mandatory_cols) ) {
			if ( ! ($cols[$i] =~ /^reference$/ && 
				$vals[$ev_code_index] =~ /^NAS$/) ) {
			    confess("no value defined for $cols[$i] in line_no $line_no line\n$line\n");
			}
			else {
			    # null dbxref entry
			    $h->{$cols[$i]} = "U:none";
			}
		    }
		    next;
		}
		if ($cols[$i] =~ /goacc/) {
		    if ($vals[$i] !~ /^GO:\d+/) {
			confess ("goacc not found in this column got ".
				 $vals[$i].
				 " instead for ".$h->{symbol}."\n");
		    }
		    else {
			$vals[$i] =~ s/GO://;
		    }
		}
		if (($cols[$i] =~ /ev_code/) &&
		    !(grep {$_ eq $vals[$i]} @ev_codes)) {
		    confess($vals[$i].
			    " is not a valid evidence code in line\n$line\n");
		}
		
		if ($cols[$i] =~ /^speciesdb$/) {
		    ($h->{$cols[$i]} = $vals[$i]) =~ tr/A-Z/a-z/;
		}	    
		elsif ($cols[$i] =~ /^reference$/) {
		    if (!($vals[$i] =~ /:/)) {
			$vals[$i] = "medline:$vals[$i]";
		    }
		    ($h->{$cols[$i]} = $vals[$i]) =~ tr/A-Z/a-z/;
		    
		}	    
		elsif ($cols[$i] =~ /^synonym/) {
		    @{$h->{$cols[$i]}} = split (/\|/, $vals[$i]);
		}
		else {
		    $h->{$cols[$i]} = $vals[$i];
		}
	    }
            if (!$h->{symbol}) {
                $h->{symbol} = $h->{full_name} || $h->{acc} || confess("No value for symbol OR full_name OR acc");
            }
            if (!$h->{reference}) {
                $h->{reference} = "$h->{speciesdb}:NOREFERENCE";
            }
	    # add product if we don't have already
	    if (!$product || $product->acc ne $h->{acc}) {
                $h->{speciesdb} || confess("speciesdb not specified");
		$product =
		  $apph->add_product(
				     {symbol=>$h->{symbol},
				      acc=>$h->{acc},
				      full_name=>$h->{full_name},
				      synonym_list=>$h->{synonym_list},
				      speciesdb=>$h->{speciesdb}});
	    
		$assoc = undef;
                $term = undef;
	    }
	    if (!$term || $term->acc != $h->{goacc}) {
#		if ($term) {
#		    printf STDERR 
#		      "new association; :%d: != :%d:\n",
#		      $term->acc, $h->{goacc};
#		}
		$term =
		  $apph->get_term({acc=>$h->{goacc}}, {id=>'y'});
		if (!$term) {
                    # maybe this is a secondary GO ID?
#                    print STDERR 
#                      "NOT A PRIMARY GO ID: $h->{goacc}\n";
                    $term =
                      $apph->get_term({synonym=>"GO:$h->{goacc}"}, {id=>'y'});
                    if ($term) {
                        push(@errors, {msg=>"$h->{goacc} is a secondary ID; ".
                                       "using ".$term->public_acc,
                                       line_no=>$line_no,
                                       line=>$line,
                                       file=>$fn});
                    }
                }
		if (!$term) {
		    my $msg = "No term with acc $h->{goacc}";
                    warn($msg);
		    confess($msg);
		    next;
		}
		$assoc =
		  $apph->add_association(
					 {#goacc=>$h->{goacc},
					  product=>$product,
					  term=>$term,
					  is_not=>$h->{is_not},
					 });
	    }
	    $apph->add_evidence({code=>$h->{ev_code},
				 seq_acc=>$h->{seq_acc},
				 reference=>$h->{reference},
				 assoc=>$assoc,
				});
	    $apph->commit;
	};
        if ($@) {
	    push(@errors, {msg=>$@, line_no=>$line_no, line=>$line, file=>$fn});
	}
    }
    $fh->close;
    push(@errors, @{$builder->error_list || []});
    $builder->error_list([]);
    $builder->per_file_report("assocs", $fn, \@errors);
    return @errors;
}

sub per_file_report {
    my $self = shift;
    my $prefix = shift;
    my $fn = shift;
    my @errors = @{shift || []};
    if (!@errors) {
        @errors = @{$self->error_list || []};
    }
    # create an individual error report for each file
    my @w = split(/\//, $fn);
    my $fh = FileHandle->new(">$prefix.$w[-1].ERR");
    foreach my $e (@errors) {
	printf $fh "\n===\n  Line:%d [%s]\n%s\n  %s\n\n", $e->{line_no}, $e->{file}, $e->{line}, $e->{msg}; 
    }
    $fh->close;
}

sub report {
    my $self = shift;
    my @errors = @{shift || []};
    if (!@errors) {
        @errors = @{$self->error_list || []};
    }
    if (@errors) {
        printf STDERR "ERRORS: %d\n", scalar(@errors);
        foreach my $e (@errors) {
            printf STDERR "\n===\n  Line:%d [%s]\n%s\n  %s\n\n", $e->{line_no}, $e->{file}, $e->{line}, $e->{msg};
        }
    }
}

1;
