BEGIN;

CREATE TEMPORARY TABLE raw_tally (case_number text,
                                  name text,
			          city text,
			          state text,
			          status text,
			          date_closed text,
			          reason_closed text,
			          date_filed text,
			          tally_date text,
			          tally_type text,
			          ballot_type text,
			          unit_id text,
			          num_of_eligible_voters int,
			          void_ballots int,
			          labor_union_1 text,
			          labor_union_2 text,
			          labor_union_3 text,
			          votes_for_labor_union_1 int,
			          votes_for_labor_union_2 int,
			          votes_for_labor_union_3 int,
			          votes_against int,
			          total_ballots_counted int,
			          challenged_ballots int,
			          challenges_are_determinative text,
			          runoff_required text,
			          union_to_certify text,
			          region text,
			          voting_unit_unit_a text,
			          voting_unit_unit_b text,
			          voting_unit_unit_c text,
			          voting_unit_unit_d text);

.mode csv
.import /dev/stdin raw_tally

INSERT INTO voting_unit (case_number, unit_id, description)
select DISTINCT t.*
FROM
  (select case_number,
	  unit_id,
	  voting_unit_unit_a
   from raw_tally
   where unit_id = 'A'
   UNION select case_number,
		unit_id,
		voting_unit_unit_a
   from raw_tally
   where unit_id = 'B'
   UNION select case_number,
		unit_id,
		voting_unit_unit_a
   from raw_tally
   where unit_id = 'C') t
LEFT JOIN voting_unit USING (case_number,
			     unit_id)
WHERE voting_unit_id is NULL;


INSERT INTO election (case_number, voting_unit_id, date, tally_type, ballot_type, unit_size)
select DISTINCT case_number,
		voting_unit_id,
		tally_date,
		rt.tally_type,
		rt.ballot_type,
		rt.num_of_eligible_voters
FROM raw_tally rt
INNER JOIN voting_unit using (case_number,
			      unit_id)
LEFT JOIN election USING (case_number,
			  voting_unit_id,
			  ballot_type)
WHERE election_id IS NULL;

select changes() || ' rows added to election';


INSERT INTO election_result (election_id,
                             total_ballots_counted,
			     void_ballots,
			     challenged_ballots,
			     challenges_are_determinative,
			     runoff_required,
			     union_to_certify)
SELECT election_id,
       rt.total_ballots_counted,
       rt.void_ballots,
       rt.challenged_ballots,
       rt.challenges_are_determinative,
       rt.runoff_required,
       rt.union_to_certify
FROM raw_tally rt
inner join voting_unit using (case_number,
			      unit_id)
inner join election using (case_number,
			   voting_unit_id,
			   ballot_type)
LEFT JOIN election_result USING (election_id)
WHERE election_result.election_id is NULL
  and date = tally_date
GROUP BY election_id;

INSERT INTO tally (election_id,
                   option,
		   votes)
SELECT distinct t.*
from
  (SELECT election_id,
	  labor_union_1,
	  votes_for_labor_union_1
   from raw_tally
   inner join voting_unit using (case_number,
				 unit_id)
   inner join election using (case_number,
			      voting_unit_id,
			      ballot_type)
   where date = tally_date
     and labor_union_1 != ''
   UNION SELECT election_id,
		labor_union_2,
		votes_for_labor_union_2
   from raw_tally
   inner join voting_unit using (case_number,
				 unit_id)
   inner join election using (case_number,
			      voting_unit_id,
			      ballot_type)
   where date = tally_date
     and labor_union_2 != ''
   UNION SELECT election_id,
		labor_union_3,
		votes_for_labor_union_3
   from raw_tally
   inner join voting_unit using (case_number,
				 unit_id)
   inner join election using (case_number,
			      voting_unit_id,
			      ballot_type)
   where date = tally_date
     and labor_union_3 != ''
   UNION SELECT election_id,
		'No union',
		votes_against
   from raw_tally
   inner join voting_unit using (case_number,
				 unit_id)
   inner join election using (case_number,
			      voting_unit_id,
			      ballot_type)
   where date = tally_date) t
LEFT JOIN tally USING (election_id)
WHERE tally.election_id IS NULL;

END;
