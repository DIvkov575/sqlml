


create or replace function sigmoid(in x float)
    returns float
    language plpgsql stable
as $$
    begin
        return 1 / (1 + power(2.718281828459045, -x));

    end;
    $$;


create or replace function fit_sigmoid (in X float[][], in y float[])
    returns lr_weights
    language plpgsql stable
as $$
declare
    bias float := 0;
    learn_rate float := 0.001;

    n_samples integer;
    n_features integer;

    weights float[];
    pred float[];
    dz float[];
    dw float[];
    db float;
begin
    n_samples = array_length(X, 1);
    n_features = array_length(X, 2);
    weights = array_fill(0.0, ARRAY[n_features]);

    for i in 1..1750 loop
        pred := ARRAY(select sigmoid(x_0::float) from unnest(dot(x, weights)) as x_0);
        dz:= ARRAY(select a-b from (select a, row_number() over() as row_num from unnest(pred) as a) t1
                join lateral (
                select b, row_number() over() as row_num from unnest(y) as b) t2
                on t1.row_num = t2.row_num
                where t1.row_num = t2.row_num);
        dw := ARRAY(select (1.0 / n_samples) * elem from unnest(dot(t(x), dz)) as elem);
        db := (1 / n_samples) * (select (sum(preds) - sum(ys)) from unnest(pred) as preds, unnest(y) as ys);

        weights := ARRAY(select weight - learn_rate * dws from (select weight, row_number() over() as row_num from unnest(weights) as weight) tb1
            join (select dws, row_number() over() as row_num from unnest(dw) as dws) tb2
            on tb1.row_num = tb2.row_num
            where tb1.row_num = tb2.row_num);
        bias := bias - learn_rate * db;
    end loop;

    return (weights, bias);
end
$$;

create or replace function predict_sigmoid(in X float[][], in weights lr_weights)
returns float[]
language plpgsql stable
as $$
    declare
    begin
        return ARRAY(select sigmoid(weighed_x + weights.bias) from unnest(dot(X, weights.weights)) as weighed_x);
    end;
$$;





create type lr_weights as
(
    weights float[],
    bias    float
);

drop function main;
create or replace function main()
returns float[]
language plpgsql
as $$
    declare
        X float[][];
        y float[];
        output float[];
        weights lr_weights;
    begin
        X := ARRAY[ARRAY[1.0, 1.0], ARRAY[0.0, 1.0], ARRAY[1.0, 1.0], ARRAY[0.0, 1.0]]::float[][];
        y := ARRAY[1.0, 0.0, 1.0, 0.0]::float[];

        weights := fit(X, y);
        output := predict(X, weights);

        return output;
    end;
    $$;
select main();
