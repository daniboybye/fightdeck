use fightslip::{
    BetSlipStore, BoutIndexRecord, SlipHandle, SlipSnapshot, SlipSnapshotListener,
};
use std::sync::{Arc, Mutex, Weak};

fn store() -> Arc<BetSlipStore> {
    let handle = SlipHandle::new(vec![
        BoutIndexRecord {
            id: "b1".into(),
            red_fighter_id: "r1".into(),
            blue_fighter_id: "u1".into(),
            winner_id: "r1".into(),
        },
        BoutIndexRecord {
            id: "b2".into(),
            red_fighter_id: "r2".into(),
            blue_fighter_id: "u2".into(),
            winner_id: "u2".into(),
        },
    ]);
    BetSlipStore::new(handle, "500.00".into()).unwrap()
}

#[derive(Default)]
struct Recorder {
    seen: Mutex<Vec<SlipSnapshot>>,
}

impl SlipSnapshotListener for Recorder {
    fn on_snapshot(&self, snapshot: SlipSnapshot) {
        self.seen.lock().unwrap().push(snapshot);
    }
}

#[test]
fn one_snapshot_carries_the_slip_the_state_and_the_balance() {
    let store = store();
    let recorder = Arc::new(Recorder::default());
    store.add_listener(recorder.clone());
    assert!(recorder.seen.lock().unwrap().is_empty(), "registering does not replay");

    store.toggle_selection("b1".into(), "r1".into(), "2.50".into());

    let seen = recorder.seen.lock().unwrap();
    assert_eq!(seen.len(), 1);
    let snapshot = &seen[0];
    assert_eq!(snapshot.slip.selections.len(), 1);
    assert_eq!(snapshot.state.mode_title, "Single");
    assert_eq!(snapshot.state.potential_return_display, "€25.00");
    assert_eq!(snapshot.balance, "500.00");
    assert_eq!(snapshot.balance_display, "€500.00");
    assert!(snapshot.state.errors.is_empty());
}

#[test]
fn errors_arrive_with_their_message() {
    let store = store();
    store.toggle_selection("b1".into(), "r1".into(), "2.50".into());
    store.set_stake("0.50".into());
    let errors = store.current_snapshot().state.errors;
    assert_eq!(errors.len(), 1);
    assert_eq!(errors[0].message, "Stake below minimum");
}

/// A listener that calls back into the store while it is being notified, as a host that
/// applies the snapshot synchronously and then reads the store would.
struct Reentrant {
    store: Mutex<Weak<BetSlipStore>>,
    reads: Mutex<Vec<usize>>,
}

impl SlipSnapshotListener for Reentrant {
    fn on_snapshot(&self, snapshot: SlipSnapshot) {
        let store = self.store.lock().unwrap().upgrade().unwrap();
        let current = store.current_snapshot();
        assert_eq!(current.slip.selections.len(), snapshot.slip.selections.len());
        self.reads.lock().unwrap().push(current.slip.selections.len());
        if snapshot.slip.selections.len() == 1 {
            // A mutation from inside the callback must not deadlock either.
            store.toggle_selection("b2".into(), "u2".into(), "1.50".into());
        }
    }
}

#[test]
fn listeners_can_reenter_the_store() {
    let store = store();
    let listener = Arc::new(Reentrant {
        store: Mutex::new(Arc::downgrade(&store)),
        reads: Mutex::new(vec![]),
    });
    store.add_listener(listener.clone());

    store.toggle_selection("b1".into(), "r1".into(), "2.50".into());

    assert_eq!(*listener.reads.lock().unwrap(), vec![1, 2]);
    assert_eq!(store.current_snapshot().state.mode_title, "Accumulator");
}

#[test]
fn a_placed_bet_leaves_its_confirmation_until_the_legs_change() {
    let store = store();
    store.toggle_selection("b1".into(), "r1".into(), "2.50".into());
    store.place_bet();

    let placed = store.current_snapshot();
    assert!(placed.slip.selections.is_empty());
    assert_eq!(placed.balance, "490.00");
    assert_eq!(placed.confirmation.as_deref(), Some("€25.00 returns if it lands"));

    // What the screen showing the confirmation can still reach does not clear it.
    store.set_stake("20.00".into());
    store.deposit("10.00".into()).unwrap();
    assert!(store.current_snapshot().confirmation.is_some());

    store.toggle_selection("b2".into(), "u2".into(), "1.50".into());
    assert_eq!(store.current_snapshot().confirmation, None);

    store.place_bet();
    store.toggle_selection("b1".into(), "r1".into(), "2.50".into());
    store.remove_selection("b1".into(), "r1".into());
    assert_eq!(store.current_snapshot().confirmation, None);
}

#[test]
fn a_slip_with_errors_is_not_placed() {
    let store = store();
    store.place_bet();
    let snapshot = store.current_snapshot();
    assert_eq!(snapshot.balance, "500.00");
    assert_eq!(snapshot.confirmation, None);
}
