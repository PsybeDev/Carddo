use rustler::NifResult;

#[rustler::nif]
fn process_move(state_json: String, action_json: String, player_id: String) -> NifResult<String> {
    todo!()
}

rustler::init!("Elixir.Carddo.Native");
